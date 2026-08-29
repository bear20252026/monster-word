import '../../../models/book.dart';
import '../../../models/word.dart';

/// Progress snapshot for session resume.
class LearningProgress {
  final Book currentBook;
  final int currentIndex;
  final List<Word> queue;

  const LearningProgress({
    required this.currentBook,
    required this.currentIndex,
    required this.queue,
  });
}

/// Port: learning progress persistence.
/// Presentation states depend on this abstraction, not on
/// `data/learning_progress_repository.dart` directly.
abstract class LearningProgressPort {
  Future<LearningProgress?> load();

  Future<void> save({
    required Book currentBook,
    required int currentIndex,
    required List<Word> queue,
  });
}
