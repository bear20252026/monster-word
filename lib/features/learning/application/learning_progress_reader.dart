/// 跨 feature 共享的「学习进度读取」契约。
///
/// 由 learning 模块实现，book 模块消费；双方只依赖本契约，不互相依赖。
/// 用于词书页展示「已学 X / 总量 Y」：统计给定词集中已掌握(learned/mastered)的单词数量。
///
/// 装配约定：learning 模块在 [lib/features/learning/...] 内实现本接口，
/// 并在其 feature scope（见 lib/app/app.dart 的外层 buildLearningFeatureScope）
/// 以 Provider`<LearningProgressReader>` 暴露；book 模块因嵌套于该 scope 之下，
/// 可直接经 context.read`<LearningProgressReader>()` 获取，无需对 learning 形成编译期依赖。
abstract interface class LearningProgressReader {
  /// 统计 [wordTexts]（如某词书的全部单词文本）中已学习/掌握的单词数量。
  Future<int> countLearnedWords(Iterable<String> wordTexts);
}
