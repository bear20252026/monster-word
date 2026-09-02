import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/checkin/data/scare_coin_checkin_writer.dart';

import 'fake_scare_coin_store.dart';

void main() {
  group('ScareCoinCheckinWriter', () {
    late FakeScareCoinStore store;
    late ScareCoinCheckinWriter writer;

    setUp(() {
      store = FakeScareCoinStore();
      writer = ScareCoinCheckinWriter(store: store);
    });

    test('checkIn 成功', () async {
      final result = await writer.checkIn();
      expect(result, isTrue);
      expect(store.dates, isNotEmpty);
    });

    test('checkIn 今天已签到时返回 false（账本幂等）', () async {
      store.lastCheckIn = FakeScareCoinStore.isoOf(DateTime.now());

      final result = await writer.checkIn();
      expect(result, isFalse);
    });

    test('getStreak 返回连续天数', () async {
      store.streakDays = 10;
      expect(await writer.getStreak(), 10);
    });
  });
}
