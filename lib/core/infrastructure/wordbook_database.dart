// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 数据层：词库数据库初始化与查询
// 跨平台支持：Windows (sqflite_common_ffi) / Android / iOS (sqflite)
import 'package:word_app/core/utils/debug_log.dart';

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:crypto/crypto.dart' show md5;
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';

// === 释义 JSON 解析器 ===
// interpret 字段存储的是复杂 JSON，结构如下：
// [
//   {
//     "t": "n.",                      // 词性
//     "def": [                        // 释义列表
//       {
//         "en": "definition",         // 英文释义
//         "cn": "中文释义",           // 中文释义
//         "p": [                      // 例句列表
//           {"en": "example", "cn": "翻译", "exams": [...]}
//         ]
//       }
//     ]
//   }
// ]

// Definition, DefExample, Word, Book 已迁移到 lib/models/
import 'package:word_app/models/word.dart';
import 'package:word_app/models/book.dart';
export 'package:word_app/models/definition.dart' show Definition, DefExample;
export 'package:word_app/models/word.dart' show Word;
export 'package:word_app/models/book.dart' show Book;

// === 词库资产大对象处理（性能审计 I20 / MEM 口径更新 2026-10） ===
//
// 旧口径：MD5 与解压都在主 isolate 同步执行（实测 ~0.3-0.6s + 2-4s UI 冻结）；
// 当时不用 compute 是怕 77MB 过 isolate 拷贝令瞬时峰值翻倍。
//
// 新口径（主 isolate 全程零大对象同步运算，forceRebuild 不再冻结 UI）：
// · 哈希：Isolate.run 直接捕获 bytes——消息拷贝 +77MB 只发生在哈希慢路径
//   （仅升级/重建走一次，版本指纹命中即整体跳过），且远小于解压路径既有
//   的 ~320MB 峰值口径；
// · 解压：主 isolate 先把 gz 落成 staging 文件（dart:io 异步写在 IO 服务
//   线程执行，不冻结 UI），后台 isolate 读 staging → decodeBytes（~320MB
//   峰值全部发生在后台）→ 原子落盘，主 isolate 随即释放 77MB 引用。
Future<String> _hashBytesInBackground(Uint8List bytes) {
  return Isolate.run(() => base64.encode(md5.convert(bytes).bytes));
}

/// gz → 目标 db 原子落盘，解码/写盘/换名全部在后台 isolate 执行。
/// 保留旧 _extractTo 的语义：解码失败清理半成品后重试一次，最后仍失败则抛出。
Future<void> _extractBytesInBackground(Uint8List gzBytes, String dbPath) async {
  final staging = '$dbPath.extract.gz';
  try {
    await File(staging).writeAsBytes(gzBytes, flush: true);
    await Isolate.run(() async {
      // BUG-STARTUP（v2.11.2）：archive 3.6.1 的文件流解码路径（decodeStream）
      // 吞吐仅 ~300-400KB/s，245MB 词库需 10 分钟以上；decodeBytes 内存解压
      // 实测 59.5MB/s（AOT 下更快，约 2-4s），代价是解压期间瞬时内存峰值
      // ~320MB（80MB gz + 242MB 明文）——现在由后台 isolate 承担，一次性可接受。
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final data = GZipDecoder().decodeBytes(File(staging).readAsBytesSync());
          final tmpDb = '$dbPath.tmp';
          await File(tmpDb).writeAsBytes(data, flush: true);
          // MW-05 双槽替换：旧库先改名 .prev 留档再切换，杜绝「旧已删、新未就位」
          // 的同时不可用窗口；切换失败可回滚 .prev（词库可由资产重解压，但可用性优先）。
          final target = File(dbPath);
          final prevPath = '$dbPath.prev';
          if (target.existsSync()) {
            try {
              final prev = File(prevPath);
              if (prev.existsSync()) {
                try {
                  prev.deleteSync();
                } catch (e, s) {
                  // 旧 .prev 是更早一代留档，删除失败不阻断（仅损失一代回滚点）
                  reportSwallowedError('词库解压：旧 .prev 清理失败', e, s);
                }
              }
              target.renameSync(prevPath);
            } catch (e, s) {
              // 改名失败（占用）：退化为直接删除目标后切换。词库事实来源是随包
              // 资产，此处只影响可用性窗口，不涉及用户不可再生数据。
              reportSwallowedError('词库解压：旧库改名 .prev 失败，退化为删除后切换', e, s);
              try {
                target.deleteSync();
              } catch (e2, s2) {
                reportSwallowedError('词库解压：旧库删除失败（rename 将随后失败）', e2, s2);
              }
            }
          }
          await File(tmpDb).rename(dbPath);
          return;
        } catch (e) {
          // MW-05 附带修复：解码失败时【绝不删除当前 dbPath】——原实现把尚可
          // 使用的旧词库一并删掉；旧库只要还在，本轮重试失败后下一次
          // initialize 仍可直接打开旧库，避免人为制造「无词库」状态。
          debugLog('[WordBookDatabase] 解压失败 (attempt ${attempt + 1}): $e');
          if (attempt == 1) rethrow;
        } finally {
          // 清理本目录内的半成品 db（staging gz 由主 isolate 统一清理）
          try {
            final sf = File('$dbPath.tmp');
            if (sf.existsSync()) await sf.delete();
          } catch (e, s) {
            // C 级（清理临时文件失败无碍主流程），留痕防「永远成功」假象。
            reportSwallowedError('词库解压：tmp 清理失败', e, s);
          }
        }
      }
    });
  } finally {
    for (final stale in [staging, '$dbPath.tmp']) {
      try {
        final sf = File(stale);
        if (sf.existsSync()) await sf.delete();
      } catch (e, s) {
        // C 级（staging 残留只占磁盘，下次启动会再清）。
        reportSwallowedError('词库解压：staging 清理失败（残留只占磁盘）', e, s);
      }
    }
  }
}

/// 词库数据库管理器（单例）
class WordBookDatabase {
  static final WordBookDatabase instance = WordBookDatabase._();
  WordBookDatabase._();

  Database? _db;
  String? _dbPath;
  bool _initialized = false;
  bool _rebuilding = false;

  /// 词库 db 文件路径（initialize/forceRebuild 成功后可用；测试注入内存库时
  /// 为 null）——供派生缓存（如中文搜索索引）定位同目录文件。
  String? get databasePathOrNull => _dbPath;

  /// A6（v2.7.42）：initialize/forceRebuild 的并发互斥屏障。
  /// 非 null 表示有一次初始化或重建正在进行，后续 initialize() 复用同一 Future，
  /// 不再各自跑一遍 35MB gz 解压/开库慢路径（复审 M7/A6：早退检查与 :193 置位
  /// 之间隔着多个 await，并发调用会重复解压并竞写同一 db 文件）。
  Completer<void>? _initCompleter;

  /// 数据库是否已初始化完成。
  /// 调用方可先检查此 getter 再访问 [db]，避免 StateError。
  bool get isInitialized => _initialized && _db != null;

  Database get db {
    if (_db == null) {
      throw StateError('数据库尚未初始化，请先调用 initialize()');
    }
    return _db!;
  }

  /// 跨平台初始化：Windows 用 FFI，Android/iOS 用原生
  static Future<void> ensurePlatform() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  static const String _kDbHashKey = 'wordbook_db_asset_hash';
  static const String _kDbVersionKey = 'wordbook_db_asset_version';

  /// 仅供测试：覆盖资产词库 bytes（绕过 rootBundle，测试环境无 assets）
  @visibleForTesting
  static Uint8List Function()? gzBytesOverrideForTest;

  /// 仅供测试：注入内存数据库，绕过 initialize()（集成测试用）。
  @visibleForTesting
  void debugInjectDbForTest(Database db) {
    _db = db;
    _initialized = true;
  }

  /// 初始化：解压词库 + 打开数据库（并发安全）。
  ///
  /// 版本管理（2026-08-30 根治"暂无单词数据"）：只检查文件存在会导致
  /// 旧版本 app 解压的旧词库永远不被新资产替换（旧库词书关联缺失 →
  /// 词书详情"暂无单词数据"、背单词 queue 为空）。现改为比对资产
  /// 词库的内容哈希，不一致即重新解压。
  ///
  /// 并发语义（A6）：多个调用方同时 initialize 只执行一次慢路径，
  /// 全部等待同一结果；失败释放互斥允许重试。
  Future<void> initialize() {
    if (_initialized) return Future.value();
    final inFlight = _initCompleter;
    if (inFlight != null) return inFlight.future;
    final completer = Completer<void>();
    _initCompleter = completer;
    // 自我监听：无人 await 时错误不逃逸为 unhandled exception
    completer.future.ignore();
    _initializeInner().then(
      (_) {
        completer.complete();
      },
      onError: (Object e, StackTrace st) {
        if (identical(_initCompleter, completer)) _initCompleter = null;
        completer.completeError(e, st);
      },
    );
    return completer.future;
  }

  Future<void> _initializeInner() async {
    await ensurePlatform();

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'wordbook.db');
    _dbPath = dbPath;
    final gzAsset = 'assets/db/wordbook.db.gz';
    final override = gzBytesOverrideForTest;

    String? extractedHash;
    String? extractedVersion;
    var canPersist = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      extractedHash = prefs.getString(_kDbHashKey);
      extractedVersion = prefs.getString(_kDbVersionKey);
      canPersist = true;
    } catch (_) {
      // prefs 不可用（测试环境/异常）时退化为"文件存在即跳过解压"
    }

    // 性能审计 P2：用版本号作资产指纹。资产词库与版本绑定发布，
    // 版本不变 → 资产哈希必不变 → 跳过 35MB gz 加载与 MD5
    // （每次冷启动省数百 ms + 内存尖峰）。极端坏库场景由下方三表自检兜底。
    String? assetVersion;
    if (override == null) {
      try {
        final info = await PackageInfo.fromPlatform();
        assetVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {
        // C 级豁免：版本号取不到仅退化为哈希比对路径，无用户可见影响
      }
    }
    final versionMatches =
        override == null &&
        assetVersion != null &&
        extractedVersion == assetVersion &&
        extractedHash != null &&
        File(dbPath).existsSync();

    Uint8List? assetBytes; // 惰性加载的资产 bytes（自检重建也可能需要）
    Future<Uint8List> loadBytes() async {
      if (override != null) return override();
      final data = await rootBundle.load(gzAsset);
      return data.buffer.asUint8List();
    }

    if (!versionMatches) {
      // 慢路径：真正需要比对/解压时才加载资产
      assetBytes = await loadBytes();
      final assetHash = await _hashBytesInBackground(assetBytes);

      if (extractedHash != assetHash || !File(dbPath).existsSync()) {
        await _extractBytesInBackground(assetBytes, dbPath);
        // MEM：解压完成立即释放 77MB 引用，后续 openDatabase/自检不再持有。
        assetBytes = null;
        if (canPersist) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kDbHashKey, assetHash);
            if (assetVersion != null) await prefs.setString(_kDbVersionKey, assetVersion);
          } catch (e, s) {
            // 错误处理审计 P3：指纹持久化失败会让每次冷启动都重走
            // 35MB gz 加载 + MD5 慢路径，性能劣化应远程可见
            reportSwallowedError('词库指纹持久化失败（冷启动将走慢路径）', e, s);
          }
        }
      } else {
        // MEM：哈希一致无需解压同样释放，后续 openDatabase/COUNT 自检零大对象持有。
        assetBytes = null;
        // 2026-10-04 审计：应用发版但词库资产未变时，版本指纹若不回写，
        // extractedVersion 永久滞留旧值 → 此后每次冷启动 versionMatches
        // 恒 false，白付 35MB gz 加载 + MD5 慢路径（连发两版即触发）。
        if (canPersist && assetVersion != null && extractedVersion != assetVersion) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kDbVersionKey, assetVersion);
          } catch (_) {
            // C 级豁免：指纹回写失败仅性能劣化（下次冷启动再走一次慢路径）
          }
        }
      }
    }

    // 打开失败（如上次解压中断留下损坏文件）→ 删库重解压一次再试
    var reopened = false;
    try {
      _db = await openDatabase(dbPath, readOnly: true);
    } catch (e, s) {
      // 词库损坏是应远程可见的事件（此前仅 debugPrint，release 不可见）
      reportSwallowedError('词库打开失败，尝试 .prev 回滚后重建', e, s);
      // MW-05：先尝试回滚上一次切换留档的 .prev（免去 2-4s 重解压）；
      // 回滚后仍打不开才走资产重解压慢路径。
      final prev = File('$dbPath.prev');
      if (prev.existsSync()) {
        try {
          final cur = File(dbPath);
          if (cur.existsSync()) await _deleteWithRetry(dbPath);
          await prev.rename(dbPath);
          _db = await openDatabase(dbPath, readOnly: true);
          reopened = true;
          reportSwallowedError('词库已从 .prev 回滚恢复', StateError('wordbook restored from .prev'), StackTrace.current);
        } catch (ePrev) {
          debugLog('[WordBookDatabase] .prev 回滚失败，走资产重解压: $ePrev');
        }
      }
      if (!reopened) {
        assetBytes ??= await loadBytes();
        await _extractBytesInBackground(assetBytes, dbPath);
        assetBytes = null;
        _db = await openDatabase(dbPath, readOnly: true);
        reopened = true;
      }
    }

    // 完整性自检：三表任一为空 = 坏库（哈希相等但内容损坏的死锁场景），
    // 强制全量重建并自检，保证离线状态下词库必然可用。
    // 审计 I22：用 LIMIT 1 存在性检查替代 COUNT(*)——语义等价（只判空），
    // words 表在大库上是 **771,251 行**（R3-D09 实测；历史上此处写「20 万+」，
    // 另有处写「3.2 万」，均已订正），COUNT 每次冷启动全表扫，EXISTS 查询 O(1)。
    if (!reopened) {
      var c = 0, w = 0, l = 0;
      try {
        c = (await db.rawQuery('SELECT 1 AS c FROM books LIMIT 1')).isEmpty ? 0 : 1;
        w = (await db.rawQuery('SELECT 1 AS c FROM words LIMIT 1')).isEmpty ? 0 : 1;
        l = (await db.rawQuery('SELECT 1 AS c FROM word_books LIMIT 1')).isEmpty ? 0 : 1;
      } catch (_) {
        // C 级豁免：自检查询失败按 0 处理走强制重建兜底
      }
      if (c == 0 || w == 0 || l == 0) {
        debugLog('[WordBookDatabase] 检测到空库/坏库(books=$c words=$w links=$l)，强制重建');
        await _db!.close();
        _db = null;
        assetBytes ??= await loadBytes();
        // MEM：哈希先行（后台 isolate），解压后即释放 77MB 引用，
        // openDatabase/持久化不再持有大对象。
        final hash = await _hashBytesInBackground(assetBytes);
        await _extractBytesInBackground(assetBytes, dbPath);
        assetBytes = null;
        _db = await openDatabase(dbPath, readOnly: true);
        if (canPersist) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kDbHashKey, hash);
            if (assetVersion != null) await prefs.setString(_kDbVersionKey, assetVersion);
          } catch (e, s) {
            reportSwallowedError('词库重建后指纹持久化失败（冷启动将走慢路径）', e, s);
          }
        }
      }
    }
    _initialized = true;
  }

  /// 全量覆盖重建词库（用户手动触发）。
  ///
  /// 不做任何新旧对比、不保留任何旧数据：关闭连接 → 删除本地旧库
  /// （含 -wal/-shm 残留）→ 从最新资产整体解压覆盖 → 重开 → 完整性统计。
  /// 返回 [DbRebuildResult]，包含三张表的计数供 UI 展示验证。
  Future<DbRebuildResult> forceRebuild() async {
    if (_rebuilding) {
      throw StateError('词库重建正在进行中，请稍候');
    }
    _rebuilding = true;
    // MEM/C1：等待 in-flight initialize 结束，避免与重建竞写同一 db 文件。
    final inflight = _initCompleter;
    if (inflight != null) {
      try {
        await inflight.future;
      } catch (e, s) {
        // 等待中的初始化失败由重建重做，但要留痕：否则首次初始化失败原因
        // 被重建入口吞掉，排障时只见「重建又成功」不见「为何需要重建」。
        reportSwallowedError('词库重建前等待 in-flight 初始化失败（将由重建重做）', e, s);
      }
    }
    // A6：重建期间到达的 initialize() 挂到屏障上等待，不再与重建竞写库文件
    final initBarrier = Completer<void>();
    initBarrier.future.ignore();
    _initCompleter = initBarrier;
    try {
      final result = await _forceRebuildInner();
      initBarrier.complete();
      return result;
    } catch (e, st) {
      if (identical(_initCompleter, initBarrier)) _initCompleter = null;
      initBarrier.completeError(e, st);
      rethrow;
    } finally {
      _rebuilding = false;
    }
  }

  /// 删除文件（Windows 占用 errno=32 为瞬态：指数退避重试 5 次）
  Future<void> _deleteWithRetry(String path) async {
    for (var i = 0; i < 5; i++) {
      final f = File(path);
      if (!f.existsSync()) return;
      try {
        f.deleteSync();
        return;
      } catch (e) {
        debugLog('[WordBookDatabase] 删除失败(${i + 1}/5): $path — $e');
        await Future.delayed(Duration(milliseconds: 150 * (i + 1)));
      }
    }
    throw FileSystemException('文件被占用，重试 5 次仍失败', path);
  }

  Future<DbRebuildResult> _forceRebuildInner() async {
    await ensurePlatform();

    // 1) 关闭现有连接（Windows 文件锁：不 close 无法覆盖文件）
    await _db?.close();
    _db = null;
    _initialized = false;

    // 2) 旧库改名 .prev 留一代回滚点（MW-05 同口径），再清 journal 残留。
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'wordbook.db');
    _dbPath = dbPath;
    try {
      final prev = File('$dbPath.prev');
      if (prev.existsSync()) await _deleteWithRetry(prev.path);
      final old = File(dbPath);
      if (old.existsSync()) old.renameSync(prev.path);
    } catch (e, s) {
      // 留档失败不阻断重建（forceRebuild 本就是显式覆盖语义），仅上报。
      reportSwallowedError('词库重建：旧库 .prev 留档失败', e, s);
      await _deleteWithRetry(dbPath);
    }
    for (final suffix in ['-wal', '-shm', '-journal']) {
      await _deleteWithRetry('$dbPath$suffix');
    }

    // 3) 从最新资产整体解压覆盖
    Uint8List? gzBytes;
    final rebuildOverride = gzBytesOverrideForTest;
    if (rebuildOverride != null) {
      gzBytes = rebuildOverride();
    } else {
      final data = await rootBundle.load('assets/db/wordbook.db.gz');
      gzBytes = data.buffer.asUint8List();
    }
    final assetHash = await _hashBytesInBackground(gzBytes);
    await _extractBytesInBackground(gzBytes, dbPath);
    // MEM：解压后立即释放，openDatabase/计数不再持有 77MB。
    gzBytes = null;

    // 4) 记录哈希，避免下次自动更新重复重建
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDbHashKey, assetHash);
    } catch (e, s) {
      // 错误处理审计 P2-6：与 :258/:313 指纹持久化同口径——指纹丢失会导致下次
      // 冷启动重走 35MB gz 加载 + 哈希慢路径，性能劣化应远程可见
      reportSwallowedError('词库重建后指纹持久化失败', e, s);
    }

    // 5) 重开并做完整性验证
    _db = await openDatabase(dbPath, readOnly: true);
    _initialized = true;

    final books = await _count('books');
    final words = await _count('words');
    final links = await _count('word_books');
    final ok = books > 0 && words > 0 && links > 0;
    return DbRebuildResult(
      books: books,
      words: words,
      links: links,
      success: ok,
      message: ok ? '词库重建完成，数据完整' : '重建后数据校验异常，请重试或反馈',
    );
  }

  Future<int> _count(String table) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return rows.isNotEmpty ? (rows.first['c'] as int? ?? 0) : 0;
  }

  /// 词库诊断信息（词书详情空态展示，用于远程定位"暂无数据"根因）
  Future<DbDiagnostics> diagnostics() async {
    var books = 0, words = 0, links = 0;
    String? error;
    var dbFileBytes = 0;
    var dbModifiedAt = '';

    try {
      final dir = await getApplicationSupportDirectory();
      final f = File(p.join(dir.path, 'wordbook.db'));
      if (f.existsSync()) {
        dbFileBytes = f.lengthSync();
        dbModifiedAt = f.lastModifiedSync().toIso8601String();
      } else {
        error = '本地词库文件不存在';
      }
      books = await _count('books');
      words = await _count('words');
      links = await _count('word_books');
    } catch (e) {
      error = e.toString();
    }

    final healthy = error == null && books > 0 && words > 0 && links > 0;
    return DbDiagnostics(
      books: books,
      words: words,
      links: links,
      dbFileBytes: dbFileBytes,
      dbModifiedAt: dbModifiedAt,
      healthy: healthy,
      error: error,
    );
  }

  /// 词书列表
  Future<List<Book>> getBooks() async {
    final rows = await db.query('books', orderBy: 'word_count DESC');
    return rows.map(Book.fromMap).toList();
  }

  /// 按词书 ID 取单词（分页）
  /// 指定词书的单词，按单词字母序 A-Z 排列（大小写不敏感）。
  ///
  /// [limit] 为 null 时全量返回——词书列表页标注的词数（books.word_count）
  /// 与词书详情页的查询结果长度必须一致，不允许任何分页截断。
  /// learning 学习队列分批加载时显式传 limit/offset。
  /// [lightweight] 列表浏览模式：不含 example/audio_urls/image_urls/phrase
  /// 大字段（实测省 ~95% 内存：example 均值 3KB）。性能审计 P1。
  /// 点进词典详情时由详情页按需重查完整词。
  Future<List<Word>> getWordsByBook(
    int bookId, {
    int? limit,
    int offset = 0,
    bool lightweight = false,
    bool randomOrder = false,
  }) async {
    // 数据层审计 P3：轻列补 main_word，与 getWordsByNames 的轻列口径一致（缺列会让 Word.mainWord 静默为空）
    final columns = lightweight ? 'id, word, main_word, interpret, uk_pron, us_pron, confuse, word_root' : '*';
    // 用户反馈修复（2026-08-31）：学习取样必须随机——字母序取前 N 会得到
    // 一整批同首字母（如全部 A 开头），事后 shuffle 无法弥补。
    //
    // 性能审计 R3-D02（复核后改写，2026-10-16）：原断言「ORDER BY RANDOM() 是
    // 元凶、改两步式提速 85×」经真库复测不成立，真正根因是 **JOIN 驱动方式**：
    //   · `JOIN word_books wb ON wb.word_id = w.id` 让 SQLite 走
    //     「SEARCH wb USING INDEX idx_wb_book → SEARCH w USING INTEGER PRIMARY KEY」，
    //     即按 word_books 的物理顺序逐行回表；而 word_books 的 word_id 是**乱序**的，
    //     于是回表变成对 words 的**随机 rowid 访问**（book 213 实测 136ms/10 行）。
    //   · 换成子查询 `w.id IN (SELECT word_id ...)` 后，words 按 rowid 顺序扫描，
    //     命中即可停（LIMIT），同书同查询 **10.5ms**（13×）。
    // 这与审计报告测出的「357ms vs 4.1ms」是同一现象的不同侧面；报告把功劳
    // 记在「去掉 RANDOM()」上，实际去掉 RANDOM() 只让 208ms→161ms（1.3×）。
    //
    // 顺序非随机（浏览器/学习页）走子查询改写，对全部 272 本书实测**无退化**
    // （大书 1.8× 提速，小书持平），且消除了「大书特慢」的长尾。
    final orderBy = 'word COLLATE NOCASE ASC';
    final rows = await db.rawQuery('''
      SELECT $columns FROM words
      WHERE id IN (SELECT word_id FROM word_books WHERE book_id = ?)
      ORDER BY $orderBy
      ${limit != null ? 'LIMIT ? OFFSET ?' : ''}
    ''', limit != null ? [bookId, limit, offset] : [bookId]);
    return rows.map(Word.fromMap).toList();
  }

  /// 按词书随机取样 [limit] 个单词。
  ///
  /// 性能审计 R3-D02：原实现 `ORDER BY RANDOM() LIMIT ?` 让 SQLite 为取 N 行把
  /// **整本书**物化进临时 B-tree（EXPLAIN 有 `USE TEMP B-TREE FOR ORDER BY`），
  /// 且叠加上面所说的随机回表问题。这里改为两步式：
  ///   ① 只取该书全部 word_id（走 idx_wb_book，12083 个 id 仅 ~9ms，纯整数列表）；
  ///   ② Dart 侧等概率抽样 k 个，再按主键 IN 批量取行（10 行 ~1.5ms）。
  /// 抽样在 Dart 侧做还顺带解决了「RANDOM() 无法按调用方种子复现」的问题。
  ///
  /// 与 SQL 的 ORDER BY RANDOM() 等概率性一致：每个词被抽中的概率为 k/N。
  Future<List<Word>> getRandomWordsByBook(
    int bookId, {
    required int limit,
    bool lightweight = false,
    Random? random,
    @visibleForTesting double? randomValueForTest,
  }) async {
    if (limit <= 0) return const [];
    // ① 该书全部词 id（覆盖索引查询，不碰 words 表）
    final idRows = await db.rawQuery('SELECT word_id FROM word_books WHERE book_id = ?', [bookId]);
    if (idRows.isEmpty) return const [];
    final ids = [for (final row in idRows) row['word_id'] as int];
    if (ids.length <= limit) {
      // 全书不足 limit：退化为整本按字母序返回，避免重复抽样
      return _wordsByIds(ids, lightweight: lightweight);
    }
    // ② 部分 Fisher-Yates：只把前 limit 个位置洗出来（O(limit)，不洗全表）
    final rng = random ?? Random();
    for (var i = 0; i < limit; i++) {
      final j = randomValueForTest != null
          ? i + (randomValueForTest * (ids.length - i)).floor().clamp(0, ids.length - i - 1)
          : i + rng.nextInt(ids.length - i);
      final tmp = ids[i];
      ids[i] = ids[j];
      ids[j] = tmp;
    }
    return _wordsByIds(ids.sublist(0, limit), lightweight: lightweight);
  }

  /// 按主键批量取词（内部工具；保持与 [getWordsByBook] 相同的列口径）。
  Future<List<Word>> _wordsByIds(List<int> ids, {required bool lightweight}) async {
    if (ids.isEmpty) return const [];
    // 数据层审计 P3：轻列补 main_word，与 getWordsByNames 的轻列口径一致
    final columns = lightweight ? 'id, word, main_word, interpret, uk_pron, us_pron, confuse, word_root' : '*';
    final result = <Word>[];
    // 分批查询，每批最多 500 个（SQLite 参数上限；与 getWordsByNames 同口径）
    for (var i = 0; i < ids.length; i += 500) {
      final batch = ids.sublist(i, (i + 500).clamp(0, ids.length));
      final placeholders = List.filled(batch.length, '?').join(',');
      final rows = await db.rawQuery('SELECT $columns FROM words WHERE id IN ($placeholders)', batch);
      result.addAll(rows.map(Word.fromMap));
    }
    // 按抽样次序返回，保持调用方拿到的顺序即随机顺序
    final byId = {for (final word in result) word.id: word};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// 词书单词总数（SQL COUNT，单值查询，不加载任何词条）。
  ///
  /// MEM/F2：分页窗口的总量口径；验收上应与 books.word_count 一致。
  Future<int> countWordsByBook(int bookId) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM word_books WHERE book_id = ?', [bookId]);
    return rows.first['c'] as int? ?? 0;
  }

  /// 词书全部单词文本（单列轻查询，按与列表一致的 A-Z 序）。
  ///
  /// MEM/F2：供「已学数按全书口径」等统计瞬时使用——只取单词文本一列
  /// （每条 ~十几字节，统计完即可 GC），调用方不得长期持有返回值。
  ///
  /// R3-D02 附带：与 [getWordsByBook] 同口径改用子查询驱动（JOIN 会让 SQLite
  /// 按 word_books 物理序回表 words ⇒ 随机 rowid 访问）。真库实测最大词书
  /// 275ms → 157ms（1.8×），其余规模持平。
  Future<List<String>> getWordTextsByBook(int bookId) async {
    final rows = await db.rawQuery(
      '''
      SELECT word FROM words
      WHERE id IN (SELECT word_id FROM word_books WHERE book_id = ?)
      ORDER BY word COLLATE NOCASE ASC
    ''',
      [bookId],
    );
    return [for (final row in rows) row['word']! as String];
  }

  /// 按单词精确查询
  Future<Word?> getWord(String word) async {
    final rows = await db.query('words', where: 'word = ?', whereArgs: [word], limit: 1);
    if (rows.isEmpty) return null;
    return Word.fromMap(rows.first);
  }

  /// 按单词列表批量查询（收藏/近义等场景）。
  /// [lightweight]=true 时不查 example/phrase 大字段（列表浏览；详情单查全量）。
  Future<List<Word>> getWordsByNames(Set<String> words, {bool lightweight = false}) async {
    if (words.isEmpty) return [];
    final result = <Word>[];
    final columns = lightweight ? 'id, word, main_word, interpret, uk_pron, us_pron, confuse, word_root' : '*';
    // 分批查询，每批最多 500 个（SQLite 参数限制）
    final wordList = words.toList();
    for (var i = 0; i < wordList.length; i += 500) {
      final batch = wordList.sublist(i, (i + 500).clamp(0, wordList.length));
      final placeholders = batch.map((_) => '?').join(',');
      final rows = await db.rawQuery('SELECT $columns FROM words WHERE word IN ($placeholders)', batch);
      result.addAll(rows.map(Word.fromMap));
    }
    return result;
  }

  /// 模糊搜索（前缀匹配）
  Future<List<Word>> searchWords(String prefix, {int limit = 20}) async {
    // 数据层审计 P3：LIKE 通配符转义（用户输入 %/_ 改变匹配语义）
    final escaped = prefix.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
    final rows = await db.query(
      'words',
      where: "word LIKE ? ESCAPE '\\'",
      whereArgs: ['$escaped%'],
      orderBy: 'word',
      limit: limit,
    );
    return rows.map(Word.fromMap).toList();
  }

  /// 单词所属词书
  Future<List<Book>> getBooksOfWord(String word) async {
    final rows = await db.rawQuery(
      '''
      SELECT b.* FROM books b
      JOIN word_books wb ON wb.book_id = b.id
      JOIN words w ON w.id = wb.word_id
      WHERE w.word = ?
    ''',
      [word],
    );
    return rows.map(Book.fromMap).toList();
  }

  /// 关闭数据库
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initialized = false;
    _initCompleter = null; // A6：允许后续 initialize 重新走完整初始化
  }
}

/// 词库全量重建结果（含完整性验证统计）
class DbRebuildResult {
  final bool success;
  final int books;
  final int words;
  final int links;
  final String message;

  const DbRebuildResult({
    required this.success,
    required this.books,
    required this.words,
    required this.links,
    required this.message,
  });

  @override
  String toString() => '重建结果: $books 本词书 / $words 词条 / $links 条关联 — $message';
}

/// 词库诊断快照
class DbDiagnostics {
  final bool healthy;
  final int books;
  final int words;
  final int links;
  final int dbFileBytes;
  final String dbModifiedAt;
  final String? error;

  const DbDiagnostics({
    required this.healthy,
    required this.books,
    required this.words,
    required this.links,
    required this.dbFileBytes,
    required this.dbModifiedAt,
    this.error,
  });
}
