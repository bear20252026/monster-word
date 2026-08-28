/// 例句值对象。
///
/// 封装一条英文例句及其中文翻译，纯数据，无外部依赖。
class ExampleSentence {
  const ExampleSentence({
    required this.english,
    required this.chinese,
    this.highlight,
  });

  /// 英文原文
  final String english;

  /// 中文翻译
  final String chinese;

  /// 高亮片段（可选）
  final String? highlight;

  bool get hasHighlight => highlight != null && highlight!.isNotEmpty;

  /// 从 `ExampleParser.parse` 返回的 Map 创建。
  factory ExampleSentence.fromParsed(Map<String, dynamic> map) {
    return ExampleSentence(
      english: (map['english'] as String?)?.trim() ?? '',
      chinese: (map['chinese'] as String?)?.trim() ?? '',
      highlight: map['highlight'] as String?,
    );
  }

  /// 从原始字段创建。
  factory ExampleSentence.fromRaw({
    required String english,
    required String chinese,
    String? highlight,
  }) {
    return ExampleSentence(
      english: english.trim(),
      chinese: chinese.trim(),
      highlight: highlight,
    );
  }
}
