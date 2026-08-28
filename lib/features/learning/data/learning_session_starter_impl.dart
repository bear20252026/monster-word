import '../../../core/learning/learning_session_starter.dart';
import '../../../models/book.dart';
import '../presentation/learning_session_state.dart';

/// 【学习功能域】把「启动会话」动作收敛为 core 契约的适配器。
///
/// 内部 hold 遗留会话状态 [LearningSessionState]，将 [startBookSession] 委托给
/// 其 [LearningSessionState.loadBook]。消费方只看到 [LearningSessionStarter]，
/// 不暴露可变会话对象。
class LearningSessionStarterImpl implements LearningSessionStarter {
  LearningSessionStarterImpl(this._session);

  final LearningSessionState _session;

  @override
  Future<void> startBookSession(Book book, {int? limit, bool shuffle = true}) {
    return _session.loadBook(book, limit: limit, shuffle: shuffle);
  }
}
