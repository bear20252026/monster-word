/// 字典补充数据领域模型（派生词/近义词/真题例句）。
///
/// 原位于 data/dictionary_extra.dart；上移 domain 后 application 端口可合法引用，
/// presentation 只消费端口与领域模型，不再 import data 层。
class DictionaryExtra {
  final List<String> derivatives; // 派生词（含简短中文注释）
  final List<String> synonyms; // 近义词
  final List<ExamSentence> examSentences; // 真题例句

  const DictionaryExtra({required this.derivatives, required this.synonyms, required this.examSentences});

  bool get isEmpty => derivatives.isEmpty && synonyms.isEmpty && examSentences.isEmpty;
}

/// 真题例句（带来源标注）
class ExamSentence {
  final String sentence;
  final String source; // 如 CET-4 / CET-6 / 考研

  const ExamSentence({required this.sentence, required this.source});
}
