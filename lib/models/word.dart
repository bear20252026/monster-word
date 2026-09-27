import 'dart:convert';

import 'package:word_app/models/definition.dart';
import 'package:word_app/models/definition_text.dart';

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

  /// 清理 HTML 标签和格式代码（如 `<font color=...>`、`<b>` 等）。
  /// 审计 I2：实现收敛到 definition_text.dart 单一真相，此处保留静态门面
  /// （工程内多处 `cleanHtml(...)` 调用点的稳定入口）。
  static String cleanHtml(String text) => cleanDefinitionHtml(text);

  /// 原始释义（清理 HTML 标签后）
  /// 如果 interpret 是 JSON 格式但解析后无有效释义，则提取所有文本值拼接
  ///
  /// 性能审计 P0-2：加实例缓存——刷词卡片拖拽期间每帧 rebuild、
  /// 学习页 hint 构建、听写页朗读前都会读本 getter，3KB JSON
  /// 每次重新解析 + 正则在低端机上可感知掉帧。
  String? _cachedCleanInterpret;

  String get cleanInterpret =>
      _cachedCleanInterpret ??= extractReadableInterpretText(interpret) ?? cleanHtml(interpret);

  /// 解释按行拆分（每个词性一行，已清理 HTML）
  List<String>? _cachedInterpretLines;

  /// 解释按行拆分（带实例缓存，MEM：列表滚动勿反复 split/清理）
  List<String> get interpretLines =>
      _cachedInterpretLines ??= cleanInterpret.split('\n').where((l) => l.trim().isNotEmpty).toList();

  String? _cachedFirstLine;

  /// 第一行释义（用于列表显示，优先结构化释义）
  String get firstInterpretLine {
    final cached = _cachedFirstLine;
    if (cached != null) return cached;
    String result;
    if (hasStructuredDefinitions) {
      final defs = parsedDefinitions;
      if (defs.isNotEmpty) {
        final first = defs.first;
        result = first.cnDef.isNotEmpty ? first.cnDef : first.enDef;
      } else {
        final lines = interpretLines;
        result = lines.isNotEmpty ? lines.first : '';
      }
    } else {
      final lines = interpretLines;
      result = lines.isNotEmpty ? lines.first : '';
    }
    return _cachedFirstLine = result;
  }

  // === JSON 释义解析 ===
  List<Definition>? _cachedDefinitions;
  bool? _cachedHasStructured;

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
    // B 级豁免：词条/词库数据解析降级，损坏数据不影响主流程（不逐条上报防刷屏，REG-OBS-001）
    _cachedDefinitions = result;
    _cachedHasStructured = result.isNotEmpty;
    return result;
  }

  /// 是否有结构化释义（JSON 格式）
  bool get hasStructuredDefinitions {
    final cached = _cachedHasStructured;
    if (cached != null) return cached;
    try {
      final decoded = jsonDecode(interpret);
      return _cachedHasStructured = decoded is List && decoded.isNotEmpty;
    } catch (_) {
      // B 级豁免：词条/词库数据解析降级，损坏数据不影响主流程（不逐条上报防刷屏，REG-OBS-001）
      return _cachedHasStructured = false;
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
