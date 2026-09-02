import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/checkin/data/scare_coin_checkin_status_reader.dart';

import 'fake_scare_coin_store.dart';

void main() {
  group('ScareCoinCheckinStatusReader', () {
    late FakeScareCoinStore store;
    late ScareCoinCheckinStatusReader reader;

    setUp(() {
      store = FakeScareCoinStore();
      reader = ScareCoinCheckinStatusReader(store: store);
    });

    test('getStatus 返回正确状态', () async {
      store.lastCheckIn = FakeScareCoinStore.isoOf(DateTime.now());
      store.streakDays = 7;
      store.dates = {'2025-03-01', '2025-03-02', '2025-03-03'};
      store.reward = 10;

      final status = await reader.getStatus();

      expect(status.todayChecked, isTrue);
      expect(status.streakDays, 7);
      expect(status.totalDays, 3);
      expect(status.reward, 10);
    });

    test('getCheckinDates 委托到账本', () async {
      store.dates = {'2025-03-01', '2025-03-05'};

      final dates = await reader.getCheckinDates();
      expect(dates, contains('2025-03-01'));
      expect(dates, contains('2025-03-05'));
      expect(dates.length, 2);
    });

    test('hasCheckedInToday 依据账本最后签到日判断', () async {
      store.lastCheckIn = '';
      expect(await reader.hasCheckedInToday(), isFalse);

      store.lastCheckIn = FakeScareCoinStore.isoOf(DateTime.now());
      expect(await reader.hasCheckedInToday(), isTrue);

      store.lastCheckIn = '2020-01-01';
      expect(await reader.hasCheckedInToday(), isFalse);
    });

    test('getStreakDays 委托到账本', () async {
      store.streakDays = 15;
      expect(await reader.getStreakDays(), 15);
    });
  });
}
