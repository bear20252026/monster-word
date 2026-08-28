import '../../models/book.dart';

/// 「启动一个词书会话」的共享 core 契约（只写不读）。
///
/// 消费方（如 book 词书页的「开始学习」动作）只需依赖本契约发起启动，而无需
/// 接触可变、承载大量状态的学习会话对象 [LearningSessionState]。规则与
/// [LearningFavoritesStore] / [NewWordsStore] 一致：features 只依赖本契约，
/// 由 learning 功能域暴露同一实现。
abstract class LearningSessionStarter {
  /// 加载词书 [book] 的单词队列并以之启动遗留刷词会话。
  ///
  /// [limit] 缺省时使用学习侧的每日目标；[shuffle] 控制是否打乱队列顺序。
  Future<void> startBookSession(Book book, {int? limit, bool shuffle = true});
}
