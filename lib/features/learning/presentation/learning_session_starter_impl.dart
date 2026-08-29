import '../../../core/learning/learning_session_reader.dart';
import 'package:word_app/core/learning/learning_session_starter.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart' show FsrsRating;
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';

/// 【学习功能域 · presentation 装配】把「启动会话」动作收敛为 core 契约的适配器。
///
/// 它持有遗留会话状态 [LearningSessionState]，将 [startBookSession] 委托给其
/// [LearningSessionState.loadBook]，将 [startWordSession] 委托给
/// [LearningSessionState.loadFromWords]，并以只读视图 [LearningSessionReader] 暴露当前词书/单词。
/// 之所以放在 presentation 层（而非 data），是因为它包装的是一个展示层状态对象，
/// 属于功能的装配/组合根；若放在 data 会造成 data -> presentation 的反向依赖，
/// 被 import_guard 的依赖方向规则拦截。消费方只看到 [LearningSessionStarter] 与
/// [LearningSessionReader]，不暴露可变会话对象。
class LearningSessionStarterImpl
    implements LearningSessionStarter, LearningSessionReader {
  LearningSessionStarterImpl(this._session);

  final LearningSessionState _session;

  @override
  Future<void> startBookSession(Book book, {int? limit, bool shuffle = true}) {
    return _session.loadBook(book, limit: limit, shuffle: shuffle);
  }

  @override
  Future<void> startWordSession(List<Word> words, {Book? book}) {
    _session.loadFromWords(words, book: book);
    return Future.value();
  }

  @override
  Future<void> startFavoritesSession({int limit = 50}) {
    return _session.loadFavorites(limit: limit);
  }

  @override
  Future<void> rate(FsrsRating rating) {
    return _session.rate(rating);
  }

  @override
  Book? get currentBook => _session.currentBook;

  @override
  Word? get currentWord => _session.currentWord;

  @override
  List<Word> get queue => _session.queue;

  @override
  int get total => _session.total;

  @override
  int get learnedNum => _session.learnedNum;
}
