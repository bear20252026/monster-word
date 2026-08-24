// 字典补充数据加载器
// 主词库（wordbook.db）以只读方式打包发布，无法在运行时扩列；
// 派生词/近义词/真题例句等扩展字段放在 assets/db/dictionary_extra.json，
// 首次访问时一次性加载进内存，按单词小写精确匹配合并。
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// 一个词条的补充数据
class DictionaryExtra {
  final List<String> derivatives; // 派生词（含简短中文注释）
  final List<String> synonyms; // 近义词
  final List<ExamSentence> examSentences; // 真题例句

  const DictionaryExtra({
    required this.derivatives,
    required this.synonyms,
    required this.examSentences,
  });

  bool get isEmpty =>
      derivatives.isEmpty && synonyms.isEmpty && examSentences.isEmpty;
}

/// 真题例句（带来源标注）
class ExamSentence {
  final String sentence;
  final String source; // 如 CET-4 / CET-6 / 考研

  const ExamSentence({required this.sentence, required this.source});
}

class DictionaryExtraStore {
  DictionaryExtraStore._();

  static Map<String, dynamic>? _raw;
  static Future<void>? _loading;

  /// 确保数据已加载（幂等，可安全重复调用）
  static Future<void> ensureLoaded() {
    _loading ??= _load();
    return _loading!;
  }

  static Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/db/dictionary_extra.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _raw = (decoded['entries'] as Map<String, dynamic>?) ?? const {};
    } catch (_) {
      // 资产缺失或解析失败时降级为空数据，不影响主流程
      _raw = const {};
    }
  }

  /// 取某单词的补充数据；无则返回 null
  static Future<DictionaryExtra?> forWord(String word) async {
    await ensureLoaded();
    final entry = _raw?[word.toLowerCase()];
    if (entry == null) return null;
    return _parse(entry);
  }

  /// 同步版本：调用前需先 ensureLoaded()（如页面 initState 中）
  static DictionaryExtra? forWordSync(String word) {
    final entry = _raw?[word.toLowerCase()];
    if (entry == null) return null;
    return _parse(entry);
  }

  static DictionaryExtra _parse(dynamic entry) {
    if (entry is! Map<String, dynamic>) {
      return const DictionaryExtra(
        derivatives: [], synonyms: [], examSentences: []);
    }
    final derivatives = (entry['derivatives'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final synonyms = (entry['synonyms'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final examSentences = (entry['examSentences'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => ExamSentence(
            sentence: e['sentence']?.toString() ?? '',
            source: e['source']?.toString() ?? ''))
        .toList();
    return DictionaryExtra(
        derivatives: derivatives, synonyms: synonyms, examSentences: examSentences);
  }
}
