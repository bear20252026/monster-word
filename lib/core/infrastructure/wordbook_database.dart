// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 数据层：词库数据库初始化与查询
// 跨平台支持：Windows (sqflite_common_ffi) / Android / iOS (sqflite)
import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
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

    final data = await rootBundle.load(gzAsset);
    final bytes = data.buffer.asUint8List();
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
