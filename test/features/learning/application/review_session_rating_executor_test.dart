import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/core/engine/srs_engine.dart';
import 'package:word_app/core/engine/super_memory_engine.dart';
import 'package:word_app/features/learning/application/review_rating_writer.dart';
import 'package:word_app/features/learning/application/review_session_rating_executor.dart';
import 'package:word_app/models/mw_word_process.dart';

void main() {
  group('ReviewSessionRatingExecutor', () {
    test('使用推进前捕获的词条写入对应 FSRS 评分并推进引擎', () async {
      String? persistedWord;
      FsrsRating? persistedRating;
      final engine = SuperMemoryEngine()..init([MwWordProcess(word: 'first'), MwWordProcess(word: 'second')]);
      final executor = ReviewSessionRatingExecutor(
        engine: engine,
        ratingWriter: ReviewRatingWriter(
          writeRating: ({required word, required rating}) async {
            persistedWord = word;
            persistedRating = rating;
          },
        ),
      );
      final reviewedWord = engine.currentWord();

      await executor.rate(reviewedWord: reviewedWord!, rating: RecallRating.good);

      expect(persistedWord, reviewedWord.word);
      expect(persistedRating, FsrsRating.good);
      expect(engine.currentWord()?.word, isNot(reviewedWord.word));
    });

    test('将不同回忆等级映射为对应的 FSRS 等级', () async {
      for (final expectation in <({RecallRating recall, FsrsRating fsrs})>[
        (recall: RecallRating.again, fsrs: FsrsRating.again),
        (recall: RecallRating.hard, fsrs: FsrsRating.hard),
        (recall: RecallRating.good, fsrs: FsrsRating.good),
        (recall: RecallRating.easy, fsrs: FsrsRating.easy),
      ]) {
        FsrsRating? persistedRating;
        final engine = SuperMemoryEngine()..init([MwWordProcess(word: expectation.recall.name)]);
        final executor = ReviewSessionRatingExecutor(
          engine: engine,
          ratingWriter: ReviewRatingWriter(
            writeRating: ({required word, required rating}) async {
              persistedRating = rating;
            },
          ),
        );

        await executor.rate(reviewedWord: engine.currentWord()!, rating: expectation.recall);

        expect(persistedRating, expectation.fsrs);
      }
    });

    test('更新评分写入端口后使用新端口，手动掌握不产生 FSRS 写入', () async {
      var oldWrites = 0;
      var newWrites = 0;
      final engine = SuperMemoryEngine()..init([MwWordProcess(word: 'first'), MwWordProcess(word: 'second')]);
      final executor = ReviewSessionRatingExecutor(
        engine: engine,
        ratingWriter: ReviewRatingWriter(writeRating: ({required word, required rating}) async => oldWrites++),
      );

      executor.updateRatingWriter(
        ReviewRatingWriter(writeRating: ({required word, required rating}) async => newWrites++),
      );
      executor.markAsKnown();
      await executor.rate(reviewedWord: engine.currentWord()!, rating: RecallRating.good);

      expect(oldWrites, 0);
      expect(newWrites, 1);
    });

    // 审计 P1-04 的回归守卫（业主 2026-10-17 选定「先保存再翻页」）。
    test('写入失败时不推进引擎并返回 false —— 不许出现「界面说完成、记录却没存」', () async {
      final engine = SuperMemoryEngine()..init([MwWordProcess(word: 'first'), MwWordProcess(word: 'second')]);
      final executor = ReviewSessionRatingExecutor(
        engine: engine,
        ratingWriter: ReviewRatingWriter(
          writeRating: ({required word, required rating}) async => throw StateError('磁盘满'),
        ),
      );
      final reviewedWord = engine.currentWord();

      final ok = await executor.rate(reviewedWord: reviewedWord!, rating: RecallRating.good);

      expect(ok, isFalse);
      expect(engine.currentWord()?.word, reviewedWord.word, reason: '写不进去就必须停在本题；推进了就等于告诉用户「这题复习完了」，而记录其实丢了');
    });
  });
}
