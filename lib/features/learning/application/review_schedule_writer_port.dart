import 'package:word_app/core/engine/fsrs6_engine.dart';

/// Port: review schedule mutations (rate / forget).
/// Presentation states depend on this abstraction, not on
/// `data/review_schedule_repository.dart` directly.
abstract class ReviewScheduleWriterPort {
  Future<void> rateWord({required String word, required FsrsRating rating});

  Future<void> forget(String word);
}
