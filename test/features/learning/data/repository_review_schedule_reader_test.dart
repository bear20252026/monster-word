import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/data/repository_review_schedule_reader.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('只读适配器委托卡片和今日统计查询', () async {
    final repository = ReviewScheduleRepository();
    await repository.initialize();
    await repository.rateWord(word: 'reader-word', rating: FsrsRating.good);

    final reader = RepositoryReviewScheduleReader(repository: repository);

    expect(reader.cardFor('reader-word'), isNotNull);
    expect(reader.cardFor('missing-word'), isNull);
    expect(reader.todayLearnCount, 1);
    expect(reader.todayReviewCount, 0);
    expect(reader.getStatusText(reader.cardFor('reader-word')!), isNotEmpty);
    expect(reader.getDifficultyText(reader.cardFor('reader-word')!), isNotEmpty);

    reader.dispose();
  });

  test('适配器转发排程变化通知', () async {
    final repository = ReviewScheduleRepository();
    await repository.initialize();
    final reader = RepositoryReviewScheduleReader(repository: repository);
    var notifications = 0;
    reader.addListener(() => notifications++);

    await repository.rateWord(word: 'notified-word', rating: FsrsRating.good);

    expect(notifications, greaterThanOrEqualTo(1));
    reader.dispose();
  });
}
