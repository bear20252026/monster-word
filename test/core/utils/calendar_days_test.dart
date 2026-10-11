// calendar_days 单测：DST 跳日族回归锚点（2026-10-08 审计收口）。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/calendar_days.dart';

void main() {
  group('calendarDaysBetween', () {
    test('同日为 0，含跨午夜邻近时刻', () {
      final a = DateTime(2026, 10, 8, 23, 59);
      final b = DateTime(2026, 10, 8, 0, 1);
      expect(calendarDaysBetween(a, b), 0);
      expect(calendarDaysBetween(b, a), 0);
    });

    test('昨天 23:59 → 今天 00:01 恰好 1 天（绝对时长不足 1h）', () {
      expect(calendarDaysBetween(DateTime(2026, 10, 7, 23, 59), DateTime(2026, 10, 8, 0, 1)), 1);
    });

    test('整个 10 月跨度按日历日计', () {
      expect(calendarDaysBetween(DateTime(2026, 10, 1), DateTime(2026, 10, 31)), 30);
      expect(calendarDaysBetween(DateTime(2026, 10, 31), DateTime(2026, 10, 1)), -30);
    });

    test('跨年为负/正对称', () {
      expect(calendarDaysBetween(DateTime(2025, 12, 31), DateTime(2026, 1, 1)), 1);
      expect(calendarDaysBetween(DateTime(2026, 1, 1), DateTime(2025, 12, 31)), -1);
    });
  });

  group('calendarDayBefore / calendarDayAdd（分量构造）', () {
    test('月初回退到上月末', () {
      final prev = calendarDayBefore(DateTime(2026, 3, 1));
      expect((prev.year, prev.month, prev.day), (2026, 2, 28));
    });

    test('闰年二月', () {
      final prev = calendarDayBefore(DateTime(2024, 3, 1));
      expect((prev.year, prev.month, prev.day), (2024, 2, 29));
    });

    test('加负数天等于回退', () {
      final d = DateTime(2026, 10, 8);
      expect(calendarDayAdd(d, -3), DateTime(2026, 10, 5));
      expect(calendarDayAdd(d, 0), d);
    });

    test('时刻分量保留（提醒排程锚点：今天 20:00 + 1 = 明天 20:00）', () {
      final d = DateTime(2026, 10, 8, 20, 5);
      final next = calendarDayAdd(d, 1);
      expect((next.year, next.month, next.day), (2026, 10, 9));
      expect((next.hour, next.minute), (20, 5));
      final prev = calendarDayBefore(d);
      expect((prev.year, prev.month, prev.day), (2026, 10, 7));
      expect((prev.hour, prev.minute), (20, 5));
    });

    test('与 calendarDaysBetween 互逆（连续步进 400 天不漂移）', () {
      var d = DateTime(2024, 1, 1);
      for (var i = 1; i <= 400; i++) {
        final next = calendarDayAdd(d, 1);
        expect(calendarDaysBetween(d, next), 1, reason: '步进第 $i 天漂移');
        d = next;
      }
    });
  });
}
