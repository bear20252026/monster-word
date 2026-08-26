// ReviewService — 复习流程业务逻辑

import '../../engine/core_engine.dart' show WordChoicePair;
import '../../engine/fsrs6_engine.dart' show FsrsRating;
import '../../models/bb_word_process.dart';
import '../../models/word.dart';

/// 复习流程服务接口
///
/// 负责编排复习流程：初始化、展示单词、评分、四选一选项生成。
abstract class ReviewService {
  /// 初始化复习引擎
  void init(List<BBWordProcess> dueWords);

  /// 获取当前复习单词
  Word? currentWord();

  /// 获取当前复习单词（字符串，兼容旧接口）
  String? get currentWordString;

  /// 获取总复习数
  int get totalNum;

  /// 获取四个选项（用于四选一）
  List<WordChoicePair> confuseItemsForChoice(Word current);

  /// 我不知道
  void iDontKnow();

  /// 模糊
  void iMayKnow();

  /// 认识
  void iReallyKnow();

  /// 太简单
  void tooEasy();

  /// 加载复习队列
  Future<void> loadReviewQueue();

  /// 评分
  Future<void> rateCurrent(int quality);

  /// 是否还有更多
  bool get hasMore;

  /// 当前进度
  (int current, int total) get progress;

  /// 对单词进行评分
  Future<void> rateWord(String word, FsrsRating rating);

  /// 重置单词卡片
  Future<void> resetCard(String word);
}
