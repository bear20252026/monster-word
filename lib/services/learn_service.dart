// 由 Claude 团队生成 | Monster Word App
// LearnService — 学习流程业务逻辑

import '../../models/word.dart';

/// 学习流程服务接口
/// 
/// 负责编排学习流程：加载词书、生成4选1题目、评分、下一词。
/// UI 层通过此接口与学习引擎交互，不直接依赖 Fsrs6Engine 等具体实现。
abstract class LearnService {
  /// 加载词书（准备学习队列）
  Future<void> loadBook(int bookId, {int limit = 50, int offset = 0, bool shuffle = true});

  /// 获取当前单词
  Word? get currentWord;

  /// 获取4选1选项（当前词 + 3个干扰项）
  List<String> get multipleChoiceOptions;

  /// 检查答案是否正确
  bool checkAnswer(String selected);

  /// 获取正确答案
  String get correctAnswer;

  /// 评分（用于 SRS 算法）
  Future<void> rateWord(int quality);

  /// 跳到下一词
  Future<void> nextWord();

  /// 是否还有更多单词
  bool get hasMoreWords;

  /// 当前进度（第几个 / 总数）
  (int current, int total) get progress;

  /// 播放当前单词音频
  Future<void> playCurrentAudio();

  /// 获取收藏单词列表
  Future<List<String>> getFavoriteWords();

  /// 获取当前学习队列（用于生成4选1选项）
  List<Word> get queue;
}
