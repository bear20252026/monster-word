import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/core/utils/boss_siege.dart';
import 'package:word_app/features/learning/application/review_queue_reader.dart';
import 'package:word_app/features/learning/data/repository_review_queue_reader.dart';
import 'package:word_app/features/learning/application/review_rating_writer.dart';
import 'package:word_app/features/learning/presentation/review_session_state.dart';
import 'package:word_app/models/word.dart';

import '../../telemetry/test_helpers/spy_usage_stats_recorder.dart';

void main() {
  group('ReviewSessionState', () {
    test('初始化后生成候选项，并将推进前的实际作答词提交给评分写入端口', () async {
      String? persistedWord;
      FsrsRating? persistedRating;
      final state = ReviewSessionState(
        queueReader: const RepositoryReviewQueueReader(),
        ratingWriter: ReviewRatingWriter(
          writeRating: ({required word, required rating}) async {
            persistedWord = word;
            persistedRating = rating;
          },
        ),
      );
      final words = [Word(id: 1, word: 'first', interpret: '第一'), Word(id: 2, word: 'second', interpret: '第二')];

      await state.initialize(ReviewQueueSnapshot(dueWords: words, queueWords: const []));
      final reviewedWord = state.currentWord;

      expect(state.loadPhase, ReviewSessionLoadPhase.ready);
      expect(state.isReady, isTrue);
      expect(state.total, 2);
      expect(state.done, 0);
      expect(reviewedWord, isNotNull);
      final reviewedWordText = reviewedWord!.word;
      expect(state.choices, hasLength(4));
      expect(state.choices.where((choice) => choice.word == reviewedWordText), hasLength(1));

      final wrongChoice = state.choices.firstWhere((choice) => choice.word != reviewedWordText);
      state.selectChoice(wrongChoice.word);
      expect(state.isWrongChoiceSelected(wrongChoice.word), isTrue);
      expect(state.selectedWrongChoice, wrongChoice.word);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(state.isWrongChoiceSelected(wrongChoice.word), isFalse);
      expect(state.selectedWrongChoice, isNull);

      state.revealAnswer();
      expect(state.showAnswer, isTrue);
      await state.continueWithGoodRating();

      expect(persistedWord, reviewedWordText);
      // 审计 P1-05：这条用例此前断言的是 `good` —— 也就是**把错误行为写成了
      // 期望值**。用户刚选错、看了答案再继续，最该记 `again`；记 `good` 会让
      // 报表（记错题）与 FSRS（记记忆良好）互相矛盾，并把该词到期日推远。
      expect(persistedRating, FsrsRating.again, reason: '答错后继续必须记 again，不能记 good');
      expect(state.done, 1);
      expect(state.showAnswer, isFalse);
      expect(state.currentWord?.word, isNot(reviewedWordText));
    });

    test('没答错就继续（只看了答案）仍记 good —— 修复不能把正确路径也一起改坏', () async {
      FsrsRating? persistedRating;
      final state = ReviewSessionState(
        queueReader: const RepositoryReviewQueueReader(),
        ratingWriter: ReviewRatingWriter(
          writeRating: ({required word, required rating}) async => persistedRating = rating,
        ),
      );
      await state.initialize(
        ReviewQueueSnapshot(
          dueWords: [Word(id: 1, word: 'solo', interpret: '独自')],
          queueWords: const [],
        ),
      );

      // 不点任何选项，直接看答案再继续 —— 这是「想不起来但没作答」的路径。
      state.revealAnswer();
      await state.continueWithGoodRating();

      expect(persistedRating, FsrsRating.good, reason: '未答错时保持原语义 good');
    });

    test('初始化读取失败后保留错误状态而不是把页面当作复习完成', () async {
      final state = ReviewSessionState(
        queueReader: const _ThrowingQueueReader(),
        ratingWriter: ReviewRatingWriter(writeRating: ({required word, required rating}) async {}),
      );

      await expectLater(
        state.initialize(const ReviewQueueSnapshot(dueWords: [], queueWords: [])),
        throwsA(isA<StateError>()),
      );

      expect(state.loadPhase, ReviewSessionLoadPhase.failed);
      expect(state.hasLoadError, isTrue);
      expect(state.loadError, isA<StateError>());
      expect(state.currentWord, isNull);
      expect(state.done, 0);
    });

    test('队列走完时上报一次会话与答题口径（同一题反复点错只记一次）', () async {
      final spy = SpyUsageStatsRecorder();
      final state = ReviewSessionState(
        queueReader: const RepositoryReviewQueueReader(),
        ratingWriter: ReviewRatingWriter(writeRating: ({required word, required rating}) async {}),
        usageStats: spy,
      );
      final words = [
        Word(id: 1, word: 'first', interpret: '第一'),
        Word(id: 2, word: 'second', interpret: '第二'),
        Word(id: 3, word: 'third', interpret: '第三'),
      ];

      await state.initialize(ReviewQueueSnapshot(dueWords: words, queueWords: const []));

      // 第一题：同一个错误候选点两次（只应记一次错），再看答案继续。
      final firstWord = state.currentWord!.word;
      final wrong = state.choices.firstWhere((choice) => choice.word != firstWord);
      state.selectChoice(wrong.word);
      state.selectChoice(wrong.word);
      await state.continueWithGoodRating();

      expect(spy.studySessions, 0, reason: '队列没走完不算完成一次会话');
      expect(spy.reviewed, 0);

      // 余下两题一次答对（正确反馈驻留 600ms 结束后自动按 good 推进）。
      for (var i = 0; i < 2; i++) {
        final word = state.currentWord!.word;
        state.selectChoice(state.choices.firstWhere((choice) => choice.word == word).word);
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }

      expect(spy.studySessions, 1, reason: '一次会话只记一次');
      expect(spy.reviewed, 3);
      expect(spy.correct, 2, reason: '第一题点错过，只算两题答对');
    });

    test('开局到期词超过 120 时只装前 120 个（单局有界），并冻结 hadDueAtStart', () async {
      final due = List.generate(200, (i) => Word(id: i + 1, word: 'w$i', interpret: '释$i'));
      final state = ReviewSessionState(
        queueReader: const RepositoryReviewQueueReader(),
        ratingWriter: ReviewRatingWriter(writeRating: ({required word, required rating}) async {}),
      );

      await state.initialize(ReviewQueueSnapshot(dueWords: due, queueWords: const []));

      expect(state.hadDueAtStart, isTrue);
      expect(state.total, reviewSessionCap, reason: '一局最多 120 词，超出部分留到下一局');
      expect(state.done, 0);
    });

    test('到期为空走整本队列兜底时既不裁切也不误判成头目战（reader 行为不动）', () async {
      final queue = List.generate(200, (i) => Word(id: i + 1, word: 'w$i', interpret: '释$i'));
      final state = ReviewSessionState(
        queueReader: const RepositoryReviewQueueReader(),
        ratingWriter: ReviewRatingWriter(writeRating: ({required word, required rating}) async {}),
      );

      await state.initialize(ReviewQueueSnapshot(dueWords: const [], queueWords: queue));

      // 兜底队列不是「到期词」：保持 reader 的既有语义（整本可练），
      // 但头目战触发口径必须挡在 hadDueAtStart 这一关。
      expect(state.total, 200);
      expect(state.hadDueAtStart, isFalse);
      expect(
        resolveBossPhase(
          hadDueAtStart: state.hadDueAtStart,
          total: state.total,
          done: state.done,
          hasWord: state.currentWord != null,
          introPlayedToday: true,
        ),
        BossBattlePhase.absent,
      );
    });

    test('rate() 与 markAsKnown() 两条路径都推进头目计数（done）', () async {
      final due = List.generate(40, (i) => Word(id: i + 1, word: 'w$i', interpret: '释$i'));
      final state = ReviewSessionState(
        queueReader: const RepositoryReviewQueueReader(),
        ratingWriter: ReviewRatingWriter(writeRating: ({required word, required rating}) async {}),
      );

      await state.initialize(ReviewQueueSnapshot(dueWords: due, queueWords: const []));
      expect(state.total, legionDueThreshold);
      expect(state.done, 0);
      expect(_bossPhaseOf(state), BossBattlePhase.active, reason: '40 词开局即触发');

      // 路径一：看答案后「继续」（rate）→ done 推进。
      state.revealAnswer();
      expect(await state.continueWithGoodRating(), isTrue);
      expect(state.done, 1, reason: 'rate() 路径必须推进头目计数');
      expect(state.currentWord, isNotNull);

      // 路径二：标记「熟」（markAsKnown）→ done 同样推进。
      expect(state.markAsKnown(), isTrue);
      expect(state.done, 2, reason: 'markAsKnown() 路径必须推进头目计数');
      expect(state.currentWord, isNotNull);

      // 闩锁：答掉两题后仍 active，不因剩余数变化重算阈值。
      expect(_bossPhaseOf(state), BossBattlePhase.active);
    });
  });
}

/// 用当前会话事实求头目阶段（口径与页面协调层一致）。
BossBattlePhase _bossPhaseOf(ReviewSessionState state) => resolveBossPhase(
  hadDueAtStart: state.hadDueAtStart,
  total: state.total,
  done: state.done,
  hasWord: state.currentWord != null,
  introPlayedToday: true,
);

class _ThrowingQueueReader implements ReviewQueueReader {
  const _ThrowingQueueReader();

  @override
  Future<List<Word>> loadWords(ReviewQueueSnapshot snapshot) async {
    throw StateError('review source unavailable');
  }
}
