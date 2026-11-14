import 'package:word_app/core/repositories/word_repository.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/application/learning_progress_port.dart';
import 'package:word_app/features/learning/data/learning_progress_repository.dart';

/// Adapts [LearningProgressRepository] (data layer) to [LearningProgressPort] (application layer).
class RepositoryLearningProgressPort implements LearningProgressPort {
  final LearningProgressRepository _repository;
  final WordRepository? _wordRepository;

  RepositoryLearningProgressPort(this._repository, [this._wordRepository]);

  @override
  Future<LearningProgress?> load() async {
    final snapshot = await _repository.load();
    if (snapshot == null) return null;
    return LearningProgress(
      currentBook: Book(id: int.tryParse(snapshot.bookId) ?? 0, code: snapshot.bookId, name: '', wordCount: 0),
      currentIndex: snapshot.currentIndex,
      queue: await _hydrateQueue(snapshot.queueWordIds),
    );
  }

  /// 用户反馈修复（2026-11-14）：快照只存 id，旧实现还原成空壳词（word=''、
  /// 无释义），恢复回退分支被「无中文释义」过滤器全部滤掉 ⇒ 「继续上次学习」
  /// 闪进 0 题完成页。这里按 id 批量查真实词；查不到的 id 保留空壳（会话侧
  /// 仍按既有口径丢弃），不阻断恢复。
  Future<List<Word>> _hydrateQueue(List<int> ids) async {
    final repo = _wordRepository;
    if (repo == null || ids.isEmpty) {
      return ids.map((id) => Word(id: id, word: '')).toList();
    }
    final real = await repo.getWordsByIds(ids);
    final byId = {for (final w in real) w.id: w};
    return ids.map((id) => byId[id] ?? Word(id: id, word: '')).toList();
  }

  @override
  Future<void> save({required Book currentBook, required int currentIndex, required List<Word> queue}) {
    return _repository.save(currentBook: currentBook, currentIndex: currentIndex, queue: queue);
  }
}
