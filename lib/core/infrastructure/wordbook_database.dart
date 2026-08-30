// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 数据层：词库数据库初始化与查询
// 跨平台支持：Windows (sqflite_common_ffi) / Android / iOS (sqflite)
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:crypto/crypto.dart' show md5;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

/// 词库数据库管理器（单例）
class WordBookDatabase {
  static final WordBookDatabase instance = WordBookDatabase._();
  WordBookDatabase._();

  Database? _db;
  bool _initialized = false;

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

  /// 仅供测试：覆盖资产词库 bytes（绕过 rootBundle，测试环境无 assets）
  @visibleForTesting
  static Uint8List Function()? gzBytesOverrideForTest;

  /// 初始化：解压词库 + 打开数据库。
  ///
  /// 版本管理（2026-08-30 根治"暂无单词数据"）：只检查文件存在会导致
  /// 旧版本 app 解压的旧词库永远不被新资产替换（旧库词书关联缺失 →
  /// 词书详情"暂无单词数据"、背单词 queue 为空）。现改为比对资产
  /// 词库的内容哈希，不一致即重新解压。
  Future<void> initialize() async {
    if (_initialized) return;
    await ensurePlatform();

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'wordbook.db');
    final gzAsset = 'assets/db/wordbook.db.gz';

    final Uint8List bytes;
    final override = gzBytesOverrideForTest;
    if (override != null) {
      bytes = override();
    } else {
      final data = await rootBundle.load(gzAsset);
      bytes = data.buffer.asUint8List();
    }
    final assetHash = base64.encode(md5.convert(bytes).bytes);

    String? extractedHash;
    var canPersist = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      extractedHash = prefs.getString(_kDbHashKey);
      canPersist = true;
    } catch (_) {
      // prefs 不可用（测试环境/异常）时退化为"文件存在即跳过解压"
    }
    final needsExtract = !File(dbPath).existsSync() || extractedHash != assetHash;

    if (needsExtract) {
      final dbBytes = GZipDecoder().decodeBytes(bytes);
      await File(dbPath).writeAsBytes(dbBytes, flush: true);
      if (canPersist) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kDbHashKey, assetHash);
        } catch (_) {}
      }
    }

    _db = await openDatabase(dbPath, readOnly: true);
    _initialized = true;
  }

  /// 全量覆盖重建词库（用户手动触发）。
  ///
  /// 不做任何新旧对比、不保留任何旧数据：关闭连接 → 删除本地旧库
  /// （含 -wal/-shm 残留）→ 从最新资产整体解压覆盖 → 重开 → 完整性统计。
  /// 返回 [DbRebuildResult]，包含三张表的计数供 UI 展示验证。
  Future<DbRebuildResult> forceRebuild() async {
    await ensurePlatform();

    // 1) 关闭现有连接（Windows 文件锁：不 close 无法覆盖文件）
    await _db?.close();
    _db = null;
    _initialized = false;

    // 2) 删除旧库与 journal 残留——零旧数据残留
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'wordbook.db');
    final old = File(dbPath);
    if (old.existsSync()) old.deleteSync();
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final j = File('$dbPath$suffix');
      if (j.existsSync()) j.deleteSync();
    }

    // 3) 从最新资产整体解压覆盖
    final Uint8List gzBytes;
    final rebuildOverride = gzBytesOverrideForTest;
    if (rebuildOverride != null) {
      gzBytes = rebuildOverride();
    } else {
      final data = await rootBundle.load('assets/db/wordbook.db.gz');
      gzBytes = data.buffer.asUint8List();
    }
    final dbBytes = GZipDecoder().decodeBytes(gzBytes);
    await File(dbPath).writeAsBytes(dbBytes, flush: true);

    // 4) 记录哈希，避免下次自动更新重复重建
    final assetHash = base64.encode(md5.convert(gzBytes).bytes);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDbHashKey, assetHash);
    } catch (_) {}

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

  /// 词书列表
  Future<List<Book>> getBooks() async {
    final rows = await db.query('books', orderBy: 'word_count DESC');
    return rows.map(Book.fromMap).toList();
  }

  /// 按词书 ID 取单词（分页）
  Future<List<Word>> getWordsByBook(int bookId, {int limit = 50, int offset = 0}) async {
    final rows = await db.rawQuery(
      '''
      SELECT w.* FROM words w
      JOIN word_books wb ON wb.word_id = w.id
      WHERE wb.book_id = ?
      ORDER BY wb.rowid
      LIMIT ? OFFSET ?
    ''',
      [bookId, limit, offset],
    );
    return rows.map(Word.fromMap).toList();
  }

  /// 按单词精确查询
  Future<Word?> getWord(String word) async {
    final rows = await db.query('words', where: 'word = ?', whereArgs: [word], limit: 1);
    if (rows.isEmpty) return null;
    return Word.fromMap(rows.first);
  }

  /// 按单词列表批量查询（用于收藏单词本等场景）
  Future<List<Word>> getWordsByNames(Set<String> words) async {
    if (words.isEmpty) return [];
    final result = <Word>[];
    // 分批查询，每批最多 500 个（SQLite 参数限制）
    final wordList = words.toList();
    for (var i = 0; i < wordList.length; i += 500) {
      final batch = wordList.sublist(i, (i + 500).clamp(0, wordList.length));
      final placeholders = batch.map((_) => '?').join(',');
      final rows = await db.rawQuery('SELECT * FROM words WHERE word IN ($placeholders)', batch);
      result.addAll(rows.map(Word.fromMap));
    }
    return result;
  }

  /// 模糊搜索（前缀匹配）
  Future<List<Word>> searchWords(String prefix, {int limit = 20}) async {
    final rows = await db.query('words', where: 'word LIKE ?', whereArgs: ['$prefix%'], orderBy: 'word', limit: limit);
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
