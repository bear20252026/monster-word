import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';

/// 「当前学习会话」只读视图的共享 core 契约（只读）。
///
/// 消费方（如 book 词书选择页的「正在学习」标记、空词表守卫）只需依赖本契约读取
/// 当前词书与当前单词，而无需接触可变、承载大量状态的学习会话对象
/// [LearningSessionState]。规则与 [LearningSessionStarter] / [LearningFavoritesStore] /
/// [NewWordsStore] 一致：features 只依赖本契约，由 learning 功能域暴露同一实现。
abstract class LearningSessionReader {
  /// 当前会话选中的词书；尚未启动会话时为 null。
  Book? get currentBook;

  /// 当前会话正在学习的单词；队列为空或索引越界时为 null。
  Word? get currentWord;

  /// 当前会话的单词队列（只读快照）。
  ///
  /// 供需要拿到队列以解析词条详情的消费方（如 content 的收藏页）使用。
  List<Word> get queue;

  /// 当前会话总词数。
  ///
  /// 供 foot_mark 等页面直接用（避免依赖 [LearningSessionState].total）。
  int get total;

  /// 本轮已学词数。
  ///
  /// 供 foot_mark、学习进度条等只用读值的消费方使用。
  int get learnedNum;
}
