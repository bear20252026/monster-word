// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 数据层：词库数据库初始化与查询
// 跨平台支持：Windows (sqflite_common_ffi) / Android / iOS (sqflite)
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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

/// 解析后的释义定义
class Definition {
  final String partOfSpeech;  // 词性：n., vt., adj. 等
  final String enDef;         // 英文释义
  final String cnDef;         // 中文释义
  final List<DefExample> examples;  // 例句列表

  const Definition({
    required this.partOfSpeech,
    required this.enDef,
    required this.cnDef,
    this.examples = const [],
  });
}

/// 释义中的例句
class DefExample {
  final String en;
  final String cn;
  const DefExample({required this.en, required this.cn});
}

/// 词书模型
class Book {
  final int id;
  final String code;
  final String name;
  final int wordCount;

  Book({
    required this.id,
    required this.code,
    required this.name,
    required this.wordCount,
  });

  factory Book.fromMap(Map<String, dynamic> map) => Book(
        id: (map['id'] as int?) ?? 0,
        code: (map['code'] as String?) ?? '',
        name: (map['name'] as String?) ?? (map['code'] as String?) ?? '',
        wordCount: (map['word_count'] as int?) ?? 0,
      );
}

/// 单词模型
class Word {
  final int id;
  final String word;
  final String mainWord;
  final String interpret;
  final String ukPron;
  final String usPron;
  final String phrase;
  final String example;
  final String confuse;
  final String audioUrls;
  final String imageUrls;
  final String wordRoot;

  Word({
    required this.id,
    required this.word,
    required this.mainWord,
    required this.interpret,
    required this.ukPron,
    required this.usPron,
    required this.phrase,
    required this.example,
    required this.confuse,
    this.audioUrls = '',
    this.imageUrls = '',
    this.wordRoot = '',
  });

  factory Word.fromMap(Map<String, dynamic> map) => Word(
        id: (map['id'] as int?) ?? 0,
        word: (map['word'] as String?) ?? '',
        mainWord: (map['main_word'] as String?) ?? '',
        interpret: (map['interpret'] as String?) ?? '',
        ukPron: (map['uk_pron'] as String?) ?? '',
        usPron: (map['us_pron'] as String?) ?? '',
        phrase: (map['phrase'] as String?) ?? '',
        example: (map['example'] as String?) ?? '',
        confuse: (map['confuse'] as String?) ?? '',
        audioUrls: (map['audio_urls'] as String?) ?? '',
        imageUrls: (map['image_urls'] as String?) ?? '',
        wordRoot: (map['word_root'] as String?) ?? '',
      );

  /// 清理 HTML 标签和格式代码（如 `<font color=...>`、`<b>` 等）
  static String _cleanHtml(String text) {
    if (text.isEmpty) return '';
    // 移除所有 HTML 标签
    var result = text.replaceAll(RegExp(r'<[^>]*>'), '');
    // 移除多余的空白字符
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    // 移除残留的 HTML 实体
    result = result
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    return result;
  }

  /// 原始释义（清理 HTML 标签后）
  String get cleanInterpret => _cleanHtml(interpret);

  /// 解释按行拆分（每个词性一行，已清理 HTML）
  List<String> get interpretLines =>
      cleanInterpret.split('\n').where((l) => l.trim().isNotEmpty).toList();

  /// 第一行释义（用于列表显示）
  String get firstInterpretLine {
    final lines = interpretLines;
    return lines.isNotEmpty ? lines.first : '';
  }

  // === JSON 释义解析 ===
  List<Definition>? _cachedDefinitions;

  /// 解析后的结构化释义列表（带缓存）
  List<Definition> get parsedDefinitions {
    if (_cachedDefinitions != null) return _cachedDefinitions!;
    final result = <Definition>[];
    try {
      final decoded = jsonDecode(interpret);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map) continue;
          final pos = (item['t'] ?? item['pos'] ?? '') as String;  // 词性
          final defList = item['def'];
          if (defList is List) {
            for (final d in defList) {
              if (d is! Map) continue;
              final enDef = (d['en'] ?? d['endef'] ?? '') as String;
              final cnDef = (d['cn'] ?? d['cndef'] ?? '') as String;
              final examples = <DefExample>[];
              final pList = d['p'];
              if (pList is List) {
                for (final ex in pList) {
                  if (ex is! Map) continue;
                  final en = (ex['en'] ?? '') as String;
                  final cn = (ex['cn'] ?? '') as String;
                  if (en.isNotEmpty || cn.isNotEmpty) {
                    examples.add(DefExample(en: en, cn: cn));
                  }
                }
              }
              result.add(Definition(
                partOfSpeech: _cleanHtml(pos),
                enDef: _cleanHtml(enDef),
                cnDef: _cleanHtml(cnDef),
                examples: examples,
              ));
            }
          }
        }
      }
    } catch (_) {
      // JSON 解析失败时返回空列表，UI 会回退到 cleanInterpret
    }
    _cachedDefinitions = result;
    return result;
  }

  /// 是否有结构化释义
  bool get hasStructuredDefinitions => parsedDefinitions.isNotEmpty;

  /// 格式化后的释义文本（用于简单显示）
  String get formattedDefinitions {
    if (!hasStructuredDefinitions) return cleanInterpret;
    final sb = StringBuffer();
    String currentPos = '';
    for (final def in parsedDefinitions) {
      if (def.partOfSpeech != currentPos) {
        currentPos = def.partOfSpeech;
        if (sb.isNotEmpty) sb.writeln();
        sb.write('$currentPos ');
      }
      sb.writeln('${def.cnDef}; ${def.enDef}');
      for (final ex in def.examples) {
        sb.writeln('  • ${ex.en}  ${ex.cn}');
      }
    }
    return sb.toString().trim();
  }
}

/// 词库数据库管理器（单例）
class WordBookDatabase {
  static final WordBookDatabase instance = WordBookDatabase._();
  WordBookDatabase._();

  Database? _db;
  bool _initialized = false;

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

  /// 初始化：解压词库（首次）+ 打开数据库
  Future<void> initialize() async {
    if (_initialized) return;
    await ensurePlatform();

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'wordbook.db');
    final gzAsset = 'assets/db/wordbook.db.gz';

    // 首次启动：解压 gzip 词库
    if (!File(dbPath).existsSync()) {
      final data = await rootBundle.load(gzAsset);
      final bytes = data.buffer.asUint8List();
      final dbBytes = GZipDecoder().decodeBytes(bytes);
      await File(dbPath).writeAsBytes(dbBytes, flush: true);
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
    final rows = await db.rawQuery('''
      SELECT w.* FROM words w
      JOIN word_books wb ON wb.word_id = w.id
      WHERE wb.book_id = ?
      ORDER BY wb.rowid
      LIMIT ? OFFSET ?
    ''', [bookId, limit, offset]);
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
      final rows = await db.rawQuery(
        'SELECT * FROM words WHERE word IN ($placeholders)',
        batch,
      );
      result.addAll(rows.map(Word.fromMap));
    }
    return result;
  }

  /// 模糊搜索（前缀匹配）
  Future<List<Word>> searchWords(String prefix, {int limit = 20}) async {
    final rows = await db.query(
      'words',
      where: 'word LIKE ?',
      whereArgs: ['$prefix%'],
      orderBy: 'word',
      limit: limit,
    );
    return rows.map(Word.fromMap).toList();
  }

  /// 单词所属词书
  Future<List<Book>> getBooksOfWord(String word) async {
    final rows = await db.rawQuery('''
      SELECT b.* FROM books b
      JOIN word_books wb ON wb.book_id = b.id
      JOIN words w ON w.id = wb.word_id
      WHERE w.word = ?
    ''', [word]);
    return rows.map(Book.fromMap).toList();
  }

  /// 关闭数据库
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initialized = false;
  }
}
