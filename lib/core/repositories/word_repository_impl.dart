// 由 Claude 团队生成 | Monster Word App
// WordRepositoryImpl — 单词数据仓库实现

import 'dart:async';
import 'dart:math' show Random;

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show Database;

import 'package:word_app/core/infrastructure/cn_search_index.dart';
import 'package:word_app/core/infrastructure/wordbook_database.dart';
import 'package:word_app/core/repositories/word_repository.dart';

/// 单词数据仓库的具体实现
class WordRepositoryImpl implements WordRepository {
  WordRepositoryImpl(this._database, {CnSearchIndex? cnSearchIndex})
    : _cnIndex = cnSearchIndex ?? CnSearchIndex.instance;

  final WordBookDatabase _database;
  final CnSearchIndex _cnIndex;

  @override
  Future<List<Word>> getWordsByBookId(int bookId, {int? limit, int? offset}) async {
    // query-plan-ok: 本查询按 `ORDER BY wb.rowid`（word_books 的**聚簇序**）驱动，
    // 与 idx_wb_book 的物理序一致 ⇒ 命中即停、无需排序，不存在 R3-D02 的随机回表。
    // 真库实测 book 213 LIMIT 50 = 4.3ms（对照：改成子查询的取词路径同口径 ~9ms）。
    // 保留 JOIN 是因为这里确实要遍历 word_books 的连续区间。
    final maps = await _database.db.rawQuery(
      '''
      SELECT w.* FROM words w
      JOIN word_books wb ON wb.word_id = w.id
      WHERE wb.book_id = ?
      ORDER BY wb.rowid
      LIMIT ? OFFSET ?
      ''',
      // LIMIT -1 = SQLite 无限制语义：limit 不传即全量（REG-LEARN-001 收口，
      // 旧默认 50 会让漏传 limit 的调用方静默截断）
      [bookId, limit ?? -1, offset ?? 0],
    );
    return maps.map(Word.fromMap).toList();
  }

  @override
  Future<Word?> getWordById(int id) async {
    final db = _database.db;
    final maps = await db.query('words', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Word.fromMap(maps.first);
  }

  @override
  Future<Word?> getWordByText(String text) async {
    final db = _database.db;
    final maps = await db.query('words', where: 'word = ?', whereArgs: [text], limit: 1);
    if (maps.isEmpty) return null;
    return Word.fromMap(maps.first);
  }

  @override
  Future<List<Word>> getWordsByTexts(Iterable<String> texts) async {
    final uniqueTexts = texts.where((text) => text.isNotEmpty).toSet().toList(growable: false);
    if (uniqueTexts.isEmpty) return [];

    final db = _database.db;
    final words = <Word>[];
    const chunkSize = 900;
    for (var start = 0; start < uniqueTexts.length; start += chunkSize) {
      final end = start + chunkSize < uniqueTexts.length ? start + chunkSize : uniqueTexts.length;
      final chunk = uniqueTexts.sublist(start, end);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final maps = await db.query('words', where: 'word IN ($placeholders)', whereArgs: chunk);
      words.addAll(maps.map(Word.fromMap));
    }
    return words;
  }

  @override
  Future<List<Word>> getWordsByIds(Iterable<int> ids) async {
    final uniqueIds = ids.where((id) => id > 0).toSet().toList(growable: false);
    if (uniqueIds.isEmpty) return [];

    final db = _database.db;
    final words = <Word>[];
    const chunkSize = 900;
    for (var start = 0; start < uniqueIds.length; start += chunkSize) {
      final end = start + chunkSize < uniqueIds.length ? start + chunkSize : uniqueIds.length;
      final chunk = uniqueIds.sublist(start, end);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final maps = await db.query('words', where: 'id IN ($placeholders)', whereArgs: chunk);
      words.addAll(maps.map(Word.fromMap));
    }
    return words;
  }

  /// 数据层审计 P3：LIKE 通配符转义——用户输入 %/_/\ 会改变匹配语义
  /// （如输入 % 匹配全部行），声明 ESCAPE '\' 后按字面匹配。
  static String _escapeLike(String input) =>
      input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  /// 旧 CASE 1 的 `word LIKE 'q%'`（ASCII 大小写不敏感前缀）的 GLOB 等价形式：
  /// ASCII 字母逐字符展开为大小写字符类（'apple' → '[aA][pP][pP][lL][eE]*'），
  /// 其余字符按字面保留——与 SQLite LIKE 仅折叠 ASCII 的行为严格一致。
  /// 调用方保证 query 不含 GLOB 元字符（* ? [ ] ^）。
  static String _ciPrefixGlob(String query) {
    final sb = StringBuffer();
    for (final c in query.runes) {
      final ch = String.fromCharCode(c);
      final lower = ch.toLowerCase();
      final upper = ch.toUpperCase();
      if (c < 128 && lower != upper) {
        sb.write('[$lower$upper]');
      } else {
        sb.write(ch);
      }
    }
    sb.write('*');
    return sb.toString();
  }

  @override
  Future<List<Word>> searchWords(String query, {int? limit}) async {
    final db = _database.db;
    final cap = limit ?? 50;

    // 搜索范围（2026-09-01）：英文单词 + 中文释义（搜索框提示"英文或中文"，
    // 此前只匹配 word 列导致中文查询恒为空）。英文命中优先于中文命中。
    //
    // 性能分层（2026-09-28，审计 I12）：词库以 readOnly 打开且资产内仅有
    // BINARY 唯一索引 idx_words_word，Android 系统 SQLite 又不带 FTS5 模块，
    // 因此按旧 ORDER BY CASE 的排序语义拆三层，让英文主路径吃索引：
    //   第 1 层 word = ?                 → BINARY 唯一索引点查（同旧 CASE 0）
    //   第 2 层 word 区间 + GLOB 类 pattern → 区间约束（word >= lo AND word < hi）
    //     走 idx_words_word 官方范围扫描；GLOB 大小写字符类 pattern 只做精确过滤。
    //     注意：纯字符类 pattern（GLOB '[aA]*'）SQLite 不会优化成索引扫描（实测
    //     EXPLAIN 为 SCAN），必须配合区间约束才能吃到 BINARY 索引。
    //   第 3 层 旧全表 LIKE（word 中缀 + interpret 中文）→ 仅当上两层不足 cap
    //     才执行，NOT IN 排除已见词，CASE 0/1/2 完整保留：任何被上层跳过的
    //     前缀命中（如全大写输入）在本层仍按 CASE 1 排在其他命中之前，
    //     拼接后全局顺序与旧单条 SQL 严格一致。
    // 真库基准：test/benchmark/search_benchmark_test.dart（新旧 P95 对比）。
    final escaped = _escapeLike(query);
    final results = <Word>[];
    final seen = <String>{};

    Future<void> collect(List<Map<String, Object?>> maps) async {
      for (final m in maps) {
        final w = m['word'] as String?;
        if (w != null && !seen.add(w)) continue;
        results.add(Word.fromMap(m));
        if (results.length >= cap) return;
      }
    }

    // 第 1 层：精确（BINARY 点查，与旧 CASE WHEN word = ? 同口径）
    final exact = await db.query('words', where: 'word = ?', whereArgs: [query], limit: cap);
    await collect(exact);

    // 第 2 层：前缀（区间 + GLOB 类 pattern 走 BINARY 索引；含元字符/非 ASCII 首字符则跳过）
    if (results.length < cap && query.isNotEmpty) {
      final first = query[0];
      final isAscii = first.codeUnitAt(0) < 128;
      final hasGlobMeta = query.contains(RegExp(r'[*?\[\]^]'));
      if (isAscii && !hasGlobMeta) {
        // 区间 [query 全大写, 首字母小写+1)：任何大小写不敏感前缀命中都以
        // query 的某个大小写变体开头，BINARY 序下最小变体是全大写串（下界），
        // 且都小于首字母小写+1（上界，如 'apple' 的命中 ∈ ['APPLE', 'b')）。
        // 区间让 SQLite 走 idx_words_word 范围扫描，GLOB 类 pattern 负责精确过滤。
        // rowid 兜底平局序：NOCASE 相等的词（'apple'/'Apple'）旧全表扫描排序器
        // 稳定、按 rowid 输出（真库实测），此处显式声明同序保证拼接严格一致。
        final lo = query.toUpperCase();
        final hi = String.fromCharCode(first.toLowerCase().codeUnitAt(0) + 1);
        final maps = await db.rawQuery(
          'SELECT * FROM words WHERE word >= ? AND word < ? AND word GLOB ? '
          'ORDER BY word COLLATE NOCASE, rowid LIMIT ?',
          [lo, hi, _ciPrefixGlob(query), cap],
        );
        await collect(maps);
      }
    }

    // 第 3 层：保底全表 LIKE（word 中缀 + interpret 中文），排除已见词；
    // CASE 0/1/2 完整保留以兜住第 2 层未覆盖的前缀命中的排序位次。
    // P0-1（I12 收尾）：纯 CJK 查询优先走二元组预筛索引——候选集上跑与
    // 本层逐字等价的验证 SQL（超集性质保证结果序列一致），索引未就绪
    // （首启构建中/构建失败/词库刚重建）自动回落本层全表扫描，双轨。
    if (results.length < cap) {
      if (seen.isEmpty) {
        final wordsPath = _database.databasePathOrNull;
        if (wordsPath != null) {
          // 幂等单飞：就绪即 no-op；构建中不阻塞本次搜索（本次仍走全表）
          unawaited(
            _cnIndex.ensureBuilt(
              wordsDb: db,
              wordsPath: wordsPath,
              indexPath: p.join(p.dirname(wordsPath), CnSearchIndex.indexFileName),
            ),
          );
        }
        final maps = await _cnIndex.searchByInterpret(
          wordsDb: db,
          query: query,
          escapedQuery: escaped,
          limit: cap - results.length,
        );
        if (maps != null) {
          await collect(maps);
          return results;
        }
      }
      final like = '%$escaped%';
      final prefix = '$escaped%';
      final exclude = seen.toList();
      final placeholders = List.filled(exclude.length, '?').join(', ');
      final maps = await db.rawQuery(
        '''
      SELECT * FROM words
      WHERE (word LIKE ? ESCAPE '\\' OR interpret LIKE ? ESCAPE '\\')
        AND word NOT IN ($placeholders)
      ORDER BY
        CASE
          WHEN word = ? THEN 0
          WHEN word LIKE ? ESCAPE '\\' THEN 1
          ELSE 2
        END,
        word COLLATE NOCASE,
        rowid
      LIMIT ?
    ''',
        [like, like, ...exclude, query, prefix, cap],
      );
      await collect(maps);
    }
    return results;
  }

  @override
  Future<Map<String, dynamic>?> getWordDetails(int wordId) async {
    final word = await getWordById(wordId);
    if (word == null) return null;
    return {
      'id': word.id,
      'word': word.word,
      'interpret': word.interpret,
      'ukPron': word.ukPron,
      'usPron': word.usPron,
      'phrase': word.phrase,
      'example': word.example,
      'confuse': word.confuse,
      'audioUrls': word.audioUrls,
      'imageUrls': word.imageUrls,
      'wordRoot': word.wordRoot,
    };
  }

  @override
  Future<List<Word>> getRandomWords(int count, {int? excludeBookId}) async {
    if (count <= 0) return const [];
    final db = _database.db;
    // 安全审计 R4：words 表无 book_id 列（关联在 word_books），用子查询排除。
    //
    // 审计 I21 订正（2026-10-16 实测）：I21 曾把这里的 `NOT IN` 换成 `NOT EXISTS`，
    // 理由「NOT EXISTS 走关联索引逐行短路，不随规模劣化」——**这条只对
    // 「候选集已被 book_id 索引压小」的场景成立**；这里要的是「扫全表排除某本书」，
    // `words` 全表扫是必然的（77 万个 id 必须逐个判定），此时相关子查询会对
    // **每一行**都去探一次 word_books。
    //
    // 真库实测（771,251 行 / 232MB，排除 book 213）：
    //   · NOT EXISTS : 1,349,220ms（≈22.5 分钟）
    //   · NOT IN     :        869ms
    //   ⇒ NOT IN 快 **1552×**，且两者结果集**逐字节等价**（759,168 行完全一致）。
    //
    // EXPLAIN QUERY PLAN 的差异就是机制本身（这才是可复现的判据）：
    //   NOT EXISTS → `SCAN words` + **CORRELATED SCALAR SUBQUERY** + `SEARCH wb`
    //   NOT IN     → `SCAN words` + **LIST SUBQUERY** + `CREATE BLOOM FILTER`
    // 前者是**相关**子查询（每行重算一次、各自一次 B-tree 下降），后者**只算一次**
    // 并由 bloom filter 把逐行判定降成常数级位测试。故此处改回 NOT IN。
    //
    // ⚠️ 不要把这条结论反向套到别处：带 `WHERE wb.book_id = ?` 把候选压小的场景
    // （如 wordbook_database.getWordsByBook），NOT EXISTS 仍是更优的。
    final useExclude = excludeBookId != null;
    final excludeFilter = useExclude ? 'id NOT IN (SELECT word_id FROM word_books WHERE book_id = ?)' : null;
    // 性能审计 R3-D02（2026-10-16 复核后改写）：原 `orderBy: 'RANDOM()' LIMIT count`
    // 让 SQLite 把**整张 words 表**（77 万行 / 232MB）物化进临时 B-tree 才能取
    // count 行。改为两步式：
    //   ① 只取通过筛选的 id（纯整数列，不碰大字段）；
    //   ② Dart 侧部分 Fisher-Yates 抽样后按主键批量取行。
    // 抽样结果与 ORDER BY RANDOM() 同为无放回等概率（每词被抽中概率 count/N）。
    final idRows = await db.rawQuery(
      'SELECT id FROM words'
      '${excludeFilter != null ? ' WHERE $excludeFilter' : ''}',
      useExclude ? [excludeBookId] : null,
    );
    if (idRows.isEmpty) return const [];
    final ids = [for (final row in idRows) row['id'] as int];
    if (ids.length <= count) {
      return _wordsByIds(db, ids);
    }
    // 部分 Fisher-Yates：只洗出前 count 个位置（O(count)，不洗全表）
    final rng = Random();
    for (var i = 0; i < count; i++) {
      final j = i + rng.nextInt(ids.length - i);
      final tmp = ids[i];
      ids[i] = ids[j];
      ids[j] = tmp;
    }
    return _wordsByIds(db, ids.sublist(0, count));
  }

  /// 按主键批量取词（内部工具；分批规避 SQLite 参数上限）。
  Future<List<Word>> _wordsByIds(Database db, List<int> ids) async {
    if (ids.isEmpty) return const [];
    final result = <Word>[];
    for (var i = 0; i < ids.length; i += 500) {
      final batch = ids.sublist(i, (i + 500).clamp(0, ids.length));
      final placeholders = List.filled(batch.length, '?').join(',');
      final maps = await db.rawQuery('SELECT * FROM words WHERE id IN ($placeholders)', batch);
      result.addAll(maps.map(Word.fromMap));
    }
    // 保持抽样次序（调用方按返回顺序使用）
    final byId = {for (final word in result) word.id: word};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Future<int> updateWordStatus(int wordId, Map<String, dynamic> status) async {
    // 此兼容接口尚未实现；学习状态由学习域的专用仓储与状态管理。
    return 0;
  }
}
