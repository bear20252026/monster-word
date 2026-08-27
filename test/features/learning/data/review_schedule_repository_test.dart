import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';
import 'package:word_app/features/learning/presentation/review_queue_state.dart';
import 'package:word_app/models/word.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('按实际词评分复用既有持久化键并区分新学和复习统计', () async {
    final schedule = ReviewScheduleRepository();
    await schedule.initialize();

    await schedule.rateWord(word: 'reviewed-word', rating: FsrsRating.good);
    expect(schedule.cardFor('reviewed-word'), isNotNull);
    expect(schedule.cardFor('other-word'), isNull);
    expect(schedule.todayLearnCount, 1);
    expect(schedule.todayReviewCount, 0);

    await schedule.rateWord(word: 'reviewed-word', rating: FsrsRating.again);
    expect(schedule.todayLearnCount, 1);
    expect(schedule.todayReviewCount, 1);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ReviewScheduleRepository.cardsPrefKey), isNotEmpty);
    expect(prefs.getString(ReviewScheduleRepository.dailyStatsPrefKey), isNotEmpty);
    expect(prefs.getStringList(ReviewScheduleRepository.activeDatesPrefKey), isNotEmpty);
  });

  test('正式复习队列只从独立调度仓储计算到期词', () async {
    final dueCard = FsrsCard(
      word: 'due-word',
      difficulty: 5,
      stability: 3,
      isNew: false,
      lastReview: DateTime.now().subtract(const Duration(days: 3)),
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
    );
    SharedPreferences.setMockInitialValues({
      ReviewScheduleRepository.cardsPrefKey: jsonEncode({'due-word': dueCard.toJson()}),
    });

    final schedule = ReviewScheduleRepository();
    await schedule.initialize();
    final state = ReviewQueueState();
    state.synchronize(
      schedule: schedule,
      queue: [
        Word(word: 'queue-only'),
        Word(word: 'due-word'),
      ],
    );

    expect(state.snapshot.queueWords.map((word) => word.word), ['queue-only', 'due-word']);
    expect(state.snapshot.dueWords.map((word) => word.word), ['due-word']);
  });
}
