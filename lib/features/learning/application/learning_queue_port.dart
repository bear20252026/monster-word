import '../../../models/book.dart';
import '../../../models/word.dart';

/// Port: learning queue operations (favorites + book loading).
/// Presentation states depend on this abstraction, not on
/// `data/learning_queue_repository.dart` directly.
///
/// [limit] is nullable: when omitted, the data adapter falls back to the
/// user's configured daily learning goal (so presentation never touches
/// preferences directly).
abstract class LearningQueuePort {
  Future<List<Word>> loadFavoriteWords({required List<Word> currentQueue});

  Future<List<Word>> loadBook(Book book, {int? limit, required bool shuffle});
}
