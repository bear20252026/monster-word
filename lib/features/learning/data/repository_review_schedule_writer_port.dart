import '../../../core/engine/fsrs6_engine.dart';
import '../application/review_schedule_writer_port.dart';
import 'review_schedule_repository.dart';

/// Adapts [ReviewScheduleRepository] (data layer) to [ReviewScheduleWriterPort] (application layer).
class RepositoryReviewScheduleWriterPort implements ReviewScheduleWriterPort {
  final ReviewScheduleRepository _repository;

  RepositoryReviewScheduleWriterPort(this._repository);

  @override
  Future<void> rateWord({required String word, required FsrsRating rating}) {
    return _repository.rateWord(word: word, rating: rating);
  }

  @override
  Future<void> forget(String word) {
    return _repository.forget(word);
  }
}
