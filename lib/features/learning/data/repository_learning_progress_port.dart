import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/application/learning_progress_port.dart';
import 'package:word_app/features/learning/data/learning_progress_repository.dart';

/// Adapts [LearningProgressRepository] (data layer) to [LearningProgressPort] (application layer).
class RepositoryLearningProgressPort implements LearningProgressPort {
  final LearningProgressRepository _repository;

  RepositoryLearningProgressPort(this._repository);

  @override
  Future<LearningProgress?> load() async {
    final snapshot = await _repository.load();
    if (snapshot == null) return null;
    return LearningProgress(
      currentBook: Book(id: int.tryParse(snapshot.bookId) ?? 0, code: snapshot.bookId, name: '', wordCount: 0),
      currentIndex: snapshot.currentIndex,
      queue: snapshot.queueWordIds.map((id) => Word(id: id, word: '')).toList(),
    );
  }

  @override
  Future<void> save({required Book currentBook, required int currentIndex, required List<Word> queue}) {
    return _repository.save(currentBook: currentBook, currentIndex: currentIndex, queue: queue);
  }
}
