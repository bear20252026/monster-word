// REG-CHK-001 回归守护：签到双数据源（历史页日历恒空、连签恒 0）
//
// 症状：签到只写尖叫币账本（scare_coin.checkin_dates），另一套 CheckInService
// （check_in_records_v1 / streak_days_v1）只读从不写且 CheckinWriter 无调用方，
// 导致签到历史页日历恒空、连签天数恒 0，与签到日历不一致。
//
// 修复（v2.7.32+73，commit 837c040）：删除 CheckInService 持久化层，
// 三个 checkin 适配器（写入/历史/状态）统一直读 ScareCoinStore 单一事实来源。
//
// 本文件锁定：写入后同一账本可被历史/状态读取器读到（同源）、写入幂等、
// 三个适配器对连签天数报告一致。
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/checkin/data/scare_coin_check_in_history_reader.dart';
import 'package:word_app/features/checkin/data/scare_coin_checkin_status_reader.dart';
import 'package:word_app/features/checkin/data/scare_coin_checkin_writer.dart';

import '../features/checkin/data/fake_scare_coin_store.dart';

void main() {
  group('REG-CHK-001 签到单一事实来源', () {
    test('签到写入后，历史读取器与状态读取器都能读到同一条记录（同源）', () async {
      final store = FakeScareCoinStore();
      final writer = ScareCoinCheckinWriter(store: store);
      final history = ScareCoinCheckInHistoryReader(store: store);
      final status = ScareCoinCheckinStatusReader(store: store);

      // bug 症状复现断言：修复前历史页读的是另一套从不被写入的存储，恒为空。
      expect(await history.getCheckedDates(), isEmpty);

      final ok = await writer.checkIn();
      expect(ok, isTrue);

      final today = FakeScareCoinStore.isoOf(DateTime.now());
      expect(await history.getCheckedDates(), contains(today));
      expect(await status.hasCheckedInToday(), isTrue);
    });

    test('同一天重复签到幂等：第二次返回 false，账本不产生重复记录', () async {
      final store = FakeScareCoinStore();
      final writer = ScareCoinCheckinWriter(store: store);
      final history = ScareCoinCheckInHistoryReader(store: store);

      expect(await writer.checkIn(), isTrue);
      expect(await writer.checkIn(), isFalse);
      expect((await history.getCheckedDates()).length, 1);
    });

    test('连签天数同源：写入/历史/状态三个适配器报告一致', () async {
      final store = FakeScareCoinStore();
      final writer = ScareCoinCheckinWriter(store: store);
      final history = ScareCoinCheckInHistoryReader(store: store);
      final status = ScareCoinCheckinStatusReader(store: store);

      await writer.checkIn();
      store.streakDays = 1; // 模拟账本推导出的连签状态

      final writerStreak = await writer.getStreak();
      final historyStreak = await history.getStreak();
      final statusSnapshot = await status.getStatus();

      expect(writerStreak, 1);
      expect(historyStreak, writerStreak);
      expect(statusSnapshot.streakDays, writerStreak);
      expect(statusSnapshot.totalDays, 1);
      expect(statusSnapshot.reward, store.checkInReward);
    });
  });
}
