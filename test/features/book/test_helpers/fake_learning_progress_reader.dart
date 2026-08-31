import 'package:word_app/features/learning/application/learning_progress_reader.dart';

/// 测试用：可预设返回值的 LearningProgressReader 模拟实现。
class FakeLearningProgressReader implements LearningProgressReader {
  FakeLearningProgressReader({this.learnedCount = 0});

  int learnedCount;

  @override
  Future<int> countLearnedWords(Iterable<String> wordTexts) async => learnedCount;
}
