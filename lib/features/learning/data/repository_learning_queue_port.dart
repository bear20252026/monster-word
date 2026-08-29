import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/features/learning/data/learning_queue_repository.dart';

/// Adapts [LearningQueueRepository] (data layer) to [LearningQueuePort] (application layer).
class RepositoryLearningQueuePort implements LearningQueuePort {
  final LearningQueueRepository _repository;

  RepositoryLearningQueuePort(this._repository);

  @override
  Future<List<Word>> loadFavoriteWords({required List<Word> currentQueue}) {
    return _repository.loadFavoriteWords(currentQueue: currentQueue);
  }

  @override
  Future<List<Word>> loadBook(Book book, {int? limit, required bool shuffle}) {
    final effectiveLimit = limit ?? UserPreferences().getDailyGoal();
    return _repository.loadBook(book, limit: effectiveLimit, shuffle: shuffle);
  }
}
