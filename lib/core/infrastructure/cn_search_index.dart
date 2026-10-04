// P0-1（性能审计 I12 收尾）：中文释义搜索的二元组预筛索引（派生缓存）。
//
// 背景：words 表 3.2 万行、interpret 为大文本（库 241MB），中文查询只能走
// 第 3 层全表 LIKE（真库实测 320-400ms，桌面热缓存）。Android 系统 SQLite
// 不带 FTS5 模块，且 FTS 分词语义与 LIKE 子串语义不等价（跨标点的子串会
// 漏），无法在保持「与旧实现结果序列严格一致」契约的前提下做替换。
//
// 方案：把每行 word+interpret 中非 ASCII 连续段的相邻字符对（二元组）作为
// 倒排关系行 (bigram, word_id) 存独立索引库 search_cn_index.db（WITHOUT
// ROWID 主键表）。查询时用查询串的二元组做 PK 前缀点查、GROUP/HAVING 取
// 「全部二元组在场」的候选行（超集预筛），再联词库跑与第 3 层逐字等价的
// 验证（同 WHERE 同 ORDER BY 同 LIMIT）——任何 LIKE 子串命中必然包含其
// 全部相邻二元组（超集性质），故结果序列与全表扫描严格一致；混合查询
// （'生素('）只要含 ≥1 个相邻 CJK 对即可加速，纯 ASCII / 无相邻对查询
// 自然回退全表。
// 注：第一版曾把二元组压成 BLOB 用 LIKE 预筛——真库实测与全表持平
//（blob LIKE 仍是全表扫），倒排点查才真正吃到索引，已废弃该方案。
//
// 双轨：未就绪（首启构建中 / 构建失败 / 指纹失效重建中）或非纯 CJK 查询，
// 调用方回退旧第 3 层全表路径，行为与迁移前完全一致。
// 指纹：词库文件 size+mtime——解压重建/资产升级必变，不符即自动重建索引。
import 'dart:io';
import 'dart:isolate';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/infrastructure/wordbook_database.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

class CnSearchIndex {
  /// 测试注入口：注入索引库的打开方式（内存库）。
  CnSearchIndex({Future<Database> Function(String path)? openIndexDatabase}) : _openIndexOverride = openIndexDatabase;

  static final CnSearchIndex instance = CnSearchIndex._();

  CnSearchIndex._() : _openIndexOverride = null;

  static const String indexFileName = 'search_cn_index.db';
  static const String table = 'search_cn_bigram';
  static const String _metaTable = 'search_cn_index_meta';

  final Future<Database> Function(String path)? _openIndexOverride;

  Database? _indexDb;
  String? _indexPath;
  String? _wordsPath;
  String? _indexedFingerprint;
  bool _ready = false;
  Future<void>? _building;

  /// ATTACH/DETACH 串行闸门：attach 会改动词库连接的 schema 状态，
  /// 并发搜索间必须成对串行（FavoriteWordsDao._writeGate 同款）。
  Future<void> _gate = Future.value();

  bool get isReady => _ready;

  /// 文本中非 ASCII 连续段内的相邻字符对。查询串与建索引用同一分词，
  /// 保证「子串命中 ⊇ 查询二元组全含」的超集性质成立——混合查询（如
  /// '生素('）只要含 ≥1 个相邻 CJK 对即可加速；纯 ASCII / 无相邻对的
  /// 查询 bigrams 为空，自然回退全表。
  static List<String> bigramsOf(String text) {
    final result = <String>[];
    var prev = -1;
    for (final c in text.runes) {
      if (c >= 0x80) {
        if (prev >= 0x80) {
          result.add(String.fromCharCode(prev) + String.fromCharCode(c));
        }
        prev = c;
      } else {
        prev = -1;
      }
    }
    return result;
  }

  /// 候选预筛 + 候选集验证一体完成：把索引库 ATTACH 到词库连接上，
  /// 单条 SQL 联接出候选并按第 3 层同款 WHERE/ORDER BY/LIMIT 验证，
  /// 排序全局有序（无需临时表、无绑定变量数上限）。
  ///
  /// 返回 null 表示索引不可用（未就绪/非纯 CJK/异常），调用方回退全表扫描。
  Future<List<Map<String, Object?>>?> searchByInterpret({
    required Database wordsDb,
    required String query,
    required String escapedQuery,
    required int limit,
  }) async {
    final indexDb = _indexDb;
    if (!_ready || indexDb == null) return null;
    // P2-1（审计）：查询侧必须去重——建索引侧同一词行内每个 bigram 只存一行
    //（见 _build 的 bigramSet），而叠词查询（'人人人'/'一步一步'/'研究研究'）
    // 会产生重复 bigram，直接拿重复列表参与 `HAVING COUNT(DISTINCT bigram) = N`
    // 会因 N 虚大而恒假、永远返回空。超集性质只要求「互异 bigram 全部在场」，
    // 去重不改变命中集合；IN 列表顺序无关，占位符与参数按去重后列表生成。
    final bigrams = bigramsOf(query).toSet().toList();
    if (bigrams.isEmpty) return null;
    final path = _indexPath;
    final wordsPath = _wordsPath;
    final indexed = _indexedFingerprint;
    if (path == null || wordsPath == null || indexed == null) return null;

    // 新鲜度：词库被解压重建/资产升级（size+mtime 变化）后立即失效，
    // 本次回退全表并允许下次 ensureBuilt 重建——索引内容永不超前于词库。
    try {
      if (_fingerprintOf(wordsPath) != indexed) {
        // P2-4（审计）：失效必须可观测。结构性事实：顶部 `!_ready` 守卫会拦截
        // 后续查询，就绪周期内只有首次失效走到这里，天然每轮就绪周期只报一次。
        _ready = false;
        _building = null;
        reportSwallowedError(
          '中文搜索索引指纹失效（词库文件已重建/升级），本次回退全表扫描',
          StateError('fingerprint mismatch: indexed=$indexed'),
          StackTrace.current,
        );
        return null;
      }
    } catch (e, s) {
      // stat IO 失败同样按失效回退处理，但异常不得静默（与上方失效上报同款）。
      _ready = false;
      reportSwallowedError('中文搜索索引指纹校验失败（stat 异常），本次回退全表扫描', e, s);
      return null;
    }

    // 倒排点查交集：WHERE bigram IN (...) 走 PK(bigram, word_id) 前缀索引，
    // HAVING COUNT(DISTINCT bigram) = N 取「全部查询二元组都在场」的词行
    //（超集预筛），再联 words 做原语义验证。
    final placeholders = List.filled(bigrams.length, '?').join(', ');
    // 调用方已按第 3 层口径完成 LIKE 转义（_escapeLike），此处不再二次转义
    final like = '%$escapedQuery%';
    final prefix = '$escapedQuery%';
    final args = <Object>[...bigrams, bigrams.length, like, like, query, prefix, limit];

    try {
      return await _serialized(() async {
        await wordsDb.execute('ATTACH DATABASE ? AS cn_search_idx', [path]);
        try {
          return await wordsDb.rawQuery('''
            SELECT w.* FROM words w
            JOIN (
              SELECT word_id FROM cn_search_idx.$table
              WHERE bigram IN ($placeholders)
              GROUP BY word_id HAVING COUNT(DISTINCT bigram) = ?
            ) c ON c.word_id = w.id
            WHERE (w.word LIKE ? ESCAPE '\\' OR w.interpret LIKE ? ESCAPE '\\')
            ORDER BY
              CASE
                WHEN w.word = ? THEN 0
                WHEN w.word LIKE ? ESCAPE '\\' THEN 1
                ELSE 2
              END,
              w.word COLLATE NOCASE,
              w.rowid
            LIMIT ?
          ''', args);
        } finally {
          await wordsDb.execute('DETACH DATABASE cn_search_idx');
        }
      });
    } catch (e, s) {
      // C 级豁免：索引查询失败属缓存侧故障，回退全表扫描即可，须可观测
      reportSwallowedError('中文搜索索引查询失败，本次回退全表扫描', e, s);
      return null;
    }
  }

  /// 幂等单飞构建。就绪前 isReady=false，搜索走旧第 3 层（双轨窗口）。
  /// [wordsPath] 为词库 db 文件路径（指纹来源）；[indexPath] 为索引库路径。
  Future<void> ensureBuilt({required Database wordsDb, required String wordsPath, required String indexPath}) {
    return _building ??= _build(wordsDb, wordsPath, indexPath);
  }

  Future<void> _build(Database wordsDb, String wordsPath, String indexPath) async {
    try {
      _ready = false;
      final fingerprint = _fingerprintOf(wordsPath);
      final override = _openIndexOverride;
      final db = override != null ? await override(indexPath) : await _openIndexDefault(indexPath);
      _indexDb = db;
      _indexPath = indexPath;
      _wordsPath = wordsPath;

      // 全新索引库尚无表：先幂等建表再查指纹（否则首查即抛 no such table）。
      // WITHOUT ROWID + PK(bigram, word_id)：bigram 前缀点查即倒排取倒，
      // (bigram, word_id) 全序覆盖免二次索引。
      await db.execute(
        'CREATE TABLE IF NOT EXISTS $table (bigram TEXT NOT NULL, word_id INTEGER NOT NULL, PRIMARY KEY (bigram, word_id)) WITHOUT ROWID',
      );
      await db.execute('CREATE TABLE IF NOT EXISTS $_metaTable (key TEXT PRIMARY KEY, value TEXT NOT NULL)');

      final meta = await db.query(_metaTable, where: 'key = ?', whereArgs: ['fingerprint']);
      final countRows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
      final rowCount = countRows.isEmpty ? 0 : (countRows.first['c'] as int? ?? 0);
      if (meta.isNotEmpty && meta.first['value'] == fingerprint && rowCount > 0) {
        _indexedFingerprint = fingerprint;
        _ready = true;
        return;
      }

      await db.execute('DROP TABLE IF EXISTS $table');
      await db.execute(
        'CREATE TABLE $table (bigram TEXT NOT NULL, word_id INTEGER NOT NULL, PRIMARY KEY (bigram, word_id)) WITHOUT ROWID',
      );
      await db.execute('DELETE FROM $_metaTable');

      // 两段式构建：先分块读词库、内存收集全部 (bigram, word_id) 对
      //（真库 ~160 万对 / 峰值 ~100MB，一次性，构建完即释放），排序后
      // 顺序插入——WITHOUT ROWID 主键表按 PK 序追加可避免随机插入的
      // B-tree 页分裂（首版随机插入真库 5 分钟未完，排序后分钟内）。
      final pairs = <(String, int)>[];
      var lastId = 0;
      while (true) {
        final rows = await wordsDb.query(
          'words',
          columns: ['id', 'word', 'interpret'],
          where: 'id > ?',
          whereArgs: [lastId],
          orderBy: 'id',
          limit: 400,
        );
        if (rows.isEmpty) break;
        for (final row in rows) {
          final id = row['id']! as int;
          lastId = id;
          // 词列 + 释义列合并建对（同一词行内去重，PK 无冲突）
          final bigramSet = <String>{
            ...bigramsOf(row['word'] as String? ?? ''),
            ...bigramsOf(row['interpret'] as String? ?? ''),
          };
          for (final b in bigramSet) {
            pairs.add((b, id));
          }
        }
        // 分块让出主 isolate：读取阶段 UI 与其他查询可用
        await Future<void>.delayed(Duration.zero);
      }
      // record 未实现 Comparable：显式按 (bigram, word_id) 字典序。
      // 性能审计 P2：~160 万对的 sort 是单次同步调用（无法像读取那样分块
      // 让出），主 isolate 会被阻塞数秒——挪到后台 isolate（列表整体转移，
      // 不复制）。插入阶段仍逐批让出，UI 保持可用。
      int comparePairs((String, int) a, (String, int) b) {
        final c = a.$1.compareTo(b.$1);
        return c != 0 ? c : a.$2.compareTo(b.$2);
      }

      final sorted = await Isolate.run(() {
        pairs.sort(comparePairs);
        return pairs;
      });
      pairs
        ..clear()
        ..addAll(sorted);

      var pending = 0;
      var batch = db.batch();
      for (final (bigram, wordId) in pairs) {
        batch.insert(table, {'bigram': bigram, 'word_id': wordId});
        pending++;
        if (pending % 8000 == 0) {
          await batch.commit(noResult: true);
          batch = db.batch();
          await Future<void>.delayed(Duration.zero);
        }
      }
      if (pending % 8000 != 0) await batch.commit(noResult: true);
      await db.insert(_metaTable, {'key': 'fingerprint', 'value': fingerprint});
      _indexedFingerprint = fingerprint;
      _ready = true;
    } catch (e, s) {
      // C 级豁免：构建失败只影响加速，搜索回退全表路径，须可观测
      reportSwallowedError('中文搜索索引构建失败，搜索回退全表扫描', e, s);
      _ready = false;
    }
  }

  /// 关闭索引库连接并复位状态（测试/生命周期管理；下次 ensureBuilt 可重建）。
  Future<void> close() async {
    _ready = false;
    _building = null;
    _indexedFingerprint = null;
    final db = _indexDb;
    _indexDb = null;
    try {
      await db?.close();
    } catch (_) {
      // 关闭失败可忽略：句柄即将被丢弃
    }
  }

  static String _fingerprintOf(String wordsPath) {
    final f = File(wordsPath);
    return '${f.lengthSync()}:${f.lastModifiedSync().millisecondsSinceEpoch}';
  }

  Future<Database> _openIndexDefault(String path) async {
    await WordBookDatabase.ensurePlatform();
    return databaseFactory.openDatabase(path);
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _gate.then((_) => action());
    _gate = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}
