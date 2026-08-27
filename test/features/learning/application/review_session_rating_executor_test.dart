import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/engine/fsrs6_engine.dart';
import 'package:word_app/engine/srs_engine.dart';
import 'package:word_app/engine/super_memory_engine.dart';
import 'package:word_app/features/learning/application/review_rating_writer.dart';
import 'package:word_app/features/learning/application/review_session_rating_executor.dart';
import 'package:word_app/models/bb_word_process.dart';

void main() {
  group('ReviewSessionRatingExecutor', () {
    test('使用推进前捕获的词条写入对应 FSRS 评分并推进引擎', () async {
      String? persistedWord;
      FsrsRating? persistedRating;
      final engine = SuperMemoryEngine()..init([BBWordProcess(word: 'first'), BBWordProcess(word: 'second')]);
      final executor = ReviewSessionRatingExecutor(
        engine: engine,
        ratingWriter: ReviewRatingWriter(
          writeRating: ({required word, required rating}) async {
            persistedWord = word;
            persistedRating = rating;
          },
        ),
      );
      final reviewedWord = engine.currentWord;

      executor.rate(reviewedWord: reviewedWord!, rating: RecallRating.good);

      expect(persistedWord, 'first');
      expect(persistedRating, FsrsRating.good);
      expect(engine.currentWord?.word, isNot('first'));
    });

    test('将不同回忆等级映射为对应的 FSRS 等级', () async {
      for (final expectation in <({RecallRating recall, FsrsRating fsrs})>[
        (recall: RecallRating.again, fsrs: FsrsRating.again),
        (recall: RecallRating.hard, fsrs: FsrsRating.hard),
        (recall: RecallRating.good, fsrs: FsrsRating.good),
        (recall: RecallRating.easy, fsrs: FsrsRating.easy),
      ]) {
        FsrsRating? persistedRating;
        final engine = SuperMemoryEngine()..init([BBWordProcess(word: expectation.recall.name)]);
        final executor = ReviewSessionRatingExecutor(
          engine: engine,
          ratingWriter: ReviewRatingWriter(
            writeRating: ({required word, required rating}) async {
              persistedRating = rating;
            },
          ),
        );

        executor.rate(reviewedWord: engine.currentWord!, rating: expectation.recall);

        expect(persistedRating, expectation.fsrs);
      }
    });

    test('更新评分写入端口后使用新端口，手动掌握不产生 FSRS 写入', () async {
      var oldWrites = 0;
      var newWrites = 0;
      final engine = SuperMemoryEngine()..init([BBWordProcess(word: 'first'), BBWordProcess(word: 'second')]);
      final executor = ReviewSessionRatingExecutor(
        engine: engine,
        ratingWriter: ReviewRatingWriter(writeRating: ({required word, required rating}) async => oldWrites++),
      );

      executor.updateRatingWriter(
        ReviewRatingWriter(writeRating: ({required word, required rating}) async => newWrites++),
      );
      executor.markAsKnown();
      executor.rate(reviewedWord: engine.currentWord!, rating: RecallRating.good);

      expect(oldWrites, 0);
      expect(newWrites, 1);
    });
  });
}
