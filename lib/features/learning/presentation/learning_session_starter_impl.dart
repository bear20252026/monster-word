import '../../../core/learning/learning_session_starter.dart';
import '../../../models/book.dart';
import 'learning_session_state.dart';

/// 【学习功能域 · presentation 装配】把「启动会话」动作收敛为 core 契约的适配器。
///
/// 它持有遗留会话状态 [LearningSessionState]，将 [startBookSession] 委托给其
/// [LearningSessionState.loadBook]。之所以放在 presentation 层（而非 data），是因为
/// 它包装的是一个展示层状态对象，属于功能的装配/组合根；若放在 data 会造成
/// data -> presentation 的反向依赖，被 import_guard 的依赖方向规则拦截。
/// 消费方只看到 [LearningSessionStarter]，不暴露可变会话对象。
class LearningSessionStarterImpl implements LearningSessionStarter {
  LearningSessionStarterImpl(this._session);

  final LearningSessionState _session;

  @override
  Future<void> startBookSession(Book book, {int? limit, bool shuffle = true}) {
    return _session.loadBook(book, limit: limit, shuffle: shuffle);
  }
}
