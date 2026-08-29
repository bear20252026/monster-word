import 'dart:convert';

import 'package:word_app/models/definition.dart';

/// 单词数据模型
///
/// 从 data/wordbook_database.dart 迁移到 models/ 层，
/// 使 Repository 和 Page 层可以不依赖 data/ 层。
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
    this.id = 0,
    required this.word,
    this.mainWord = '',
    this.interpret = '',
    this.ukPron = '',
    this.usPron = '',
    this.phrase = '',
    this.example = '',
    this.confuse = '',
    this.audioUrls = '',
    this.imageUrls = '',
    this.wordRoot = '',
  });

  factory Word.fromMap(Map<String, dynamic> map) => Word(
    id: (map['id'] as num?)?.toInt() ?? 0,
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'word': word,
    'main_word': mainWord,
    'interpret': interpret,
    'uk_pron': ukPron,
    'us_pron': usPron,
    'phrase': phrase,
    'example': example,
    'confuse': confuse,
    'audio_urls': audioUrls,
    'image_urls': imageUrls,
    'word_root': wordRoot,
  };

  /// 清理 HTML 标签和格式代码（如 `<font color=...>`、`<b>` 等）
  static String cleanHtml(String text) {
    if (text.isEmpty) return '';
    var result = text.replaceAll(RegExp(r'<[^>]*>'), '');
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
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
  /// 如果 interpret 是 JSON 格式但解析后无有效释义，则提取所有文本值拼接
  String get cleanInterpret {
    final raw = cleanHtml(interpret);
    // 尝试从 JSON 中提取可读文本（处理 def 为 ID 引用的情况）
    try {
      final decoded = jsonDecode(interpret);
      if (decoded is List && decoded.isNotEmpty) {
        final texts = <String>[];
        for (final item in decoded) {
          if (item is! Map) continue;
          final pos = (item['t'] ?? item['pos'] ?? '') as String;
          if (pos.isNotEmpty) texts.add(pos);
          final defList = item['def'];
          if (defList is List) {
            for (final d in defList) {
              if (d is Map) {
                final en = (d['en'] ?? d['endef'] ?? '') as String;
                final cn = (d['cn'] ?? d['cndef'] ?? '') as String;
                if (cn.isNotEmpty) texts.add(cn);
                if (en.isNotEmpty) texts.add(en);
              }
              // 跳过整数 ID 引用（如 22285），不显示
            }
          }
        }
        if (texts.isNotEmpty) {
          return texts.join('；');
        }
      }
    } catch (_) {}
    return raw;
  }

  /// 解释按行拆分（每个词性一行，已清理 HTML）
  List<String> get interpretLines => cleanInterpret.split('\n').where((l) => l.trim().isNotEmpty).toList();

  /// 第一行释义（用于列表显示，优先结构化释义）
  String get firstInterpretLine {
    if (hasStructuredDefinitions) {
      final defs = parsedDefinitions;
      if (defs.isNotEmpty) {
        final first = defs.first;
        return first.cnDef.isNotEmpty ? first.cnDef : first.enDef;
      }
    }
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
          final pos = (item['t'] ?? item['pos'] ?? '') as String;
          final defList = item['def'];
          if (defList is List) {
            for (final d in defList) {
              if (d is! Map) continue;
              // ✅ 修复：优先获取 en/cn 字段，忽略 id 引用
              final enDef = (d['en'] ?? d['endef'] ?? '') as String;
              final cnDef = (d['cn'] ?? d['cndef'] ?? '') as String;
              result.add(Definition(partOfSpeech: cleanHtml(pos), enDef: cleanHtml(enDef), cnDef: cleanHtml(cnDef)));
            }
          }
        }
      }
    } catch (_) {}
    _cachedDefinitions = result;
    return result;
  }

  /// 是否有结构化释义（JSON 格式）
  bool get hasStructuredDefinitions {
    try {
      final decoded = jsonDecode(interpret);
      return decoded is List && decoded.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 格式化释义（用于详情页显示）
  String get formattedDefinitions {
    if (!hasStructuredDefinitions) return cleanInterpret;
    final defs = parsedDefinitions;
    final buffer = StringBuffer();
    for (final def in defs) {
      if (def.partOfSpeech.isNotEmpty) {
        buffer.writeln(def.partOfSpeech);
      }
      if (def.cnDef.isNotEmpty) {
        buffer.writeln(def.cnDef);
      }
      if (def.enDef.isNotEmpty) {
        buffer.writeln(def.enDef);
      }
    }
    final result = buffer.toString().trim();
    // ✅ 修复：如果结构化解析结果为空（def 全是 ID 引用），回退到 cleanInterpret
    return result.isNotEmpty ? result : cleanInterpret;
  }

  /// JSON 解析辅助方法
  static dynamic jsonDecode(String source) {
    return (const JsonDecoder()).convert(source);
  }
}
