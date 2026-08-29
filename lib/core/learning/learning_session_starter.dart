import '../../models/book.dart';
import '../../core/engine/fsrs6_engine.dart' show FsrsRating;
import '../../models/word.dart';

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

  /// 以给定单词 [words] 及所属词书 [book] 直接启动一个临时会话。
  ///
  /// 用于「听写/随手拼」这类不进入正式刷词队列的一次性流程：调用方先加载单词列表，
  /// 再经本契约注入会话，随后导航到对应会话页。
  Future<void> startWordSession(List<Word> words, {Book? book});

  /// 把「收藏单词本」加载进学习会话（单词本「学习」入口）。
  ///
  /// [limit] 控制加载的收藏词上限（缺省 50），防止一次性塞入过多词条。
  /// 供 content 的我的收藏页发起刷单词本会话使用。
  Future<void> startFavoritesSession({int limit = 50});

  /// 给当前会话的当前单词记录评分并推进到下一个单词。
  ///
  /// 供词书/详情页的「下一词」等评分入口使用，避免这些消费方依赖可变的学习会话
  /// 展示状态（[LearningSessionState]）来触发评分。
  Future<void> rate(FsrsRating rating);
}
