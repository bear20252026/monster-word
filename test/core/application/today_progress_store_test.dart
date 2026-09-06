import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/application/today_progress_store.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences().init();
    await UserPreferences().init();
  });

  test('目标统一写入 A 键，剩余/达标由同一 store 计算', () async {
    final store = TodayProgressStore();
    await store.setGoal(20);
    await AppPreferences().setTodayLearned(7, date: _today());
    store.sync(due: 4);

    expect(store.goal, 20);
    expect(store.learned, 7);
    expect(store.remaining, 13);
    expect(store.achieved, isFalse);
    expect(store.due, 4);
  });

  test('目标达成后 remaining=0，due 独立保留', () async {
    final store = TodayProgressStore();
    await store.setGoal(10);
    await AppPreferences().setTodayLearned(12, date: _today());
    store.sync(due: 3);

    expect(store.remaining, 0);
    expect(store.achieved, isTrue);
    expect(store.due, 3);
  });

  test('跨天 sync 自动清零旧的今日已学', () async {
    final store = TodayProgressStore();
    await store.setGoal(10);
    await AppPreferences().setTodayLearned(8, date: '2000-01-01');
    store.sync(due: 0, now: DateTime(2026, 9, 6));

    expect(store.learned, 0);
    expect(store.remaining, 10);
  });
}

String _today() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
