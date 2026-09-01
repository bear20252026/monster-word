// 学习提醒时间纯函数单测：解析合法性 + 下次触发时刻计算。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/settings/domain/reminder_time.dart';

void main() {
  group('parseReminderTime', () {
    test('合法 HH:mm 正常解析', () {
      expect(parseReminderTime('20:00'), (20, 0));
      expect(parseReminderTime('6:30'), (6, 30));
      expect(parseReminderTime(' 07:05 '), (7, 5));
      expect(parseReminderTime('23:59'), (23, 59));
    });

    test('非法输入回退默认 20:00', () {
      expect(parseReminderTime(''), (20, 0));
      expect(parseReminderTime('abc'), (20, 0));
      expect(parseReminderTime('24:00'), (20, 0)); // 小时越界
      expect(parseReminderTime('12:60'), (20, 0)); // 分钟越界
      expect(parseReminderTime('20:0'), (20, 0)); // 分钟缺位
    });
  });

  group('nextReminderOccurrence', () {
    test('今天未到 → 今天触发', () {
      final now = DateTime(2026, 9, 2, 10, 0);
      final next = nextReminderOccurrence(now, 20, 0);
      expect(next, DateTime(2026, 9, 2, 20, 0));
    });

    test('今天已过 → 明天触发', () {
      final now = DateTime(2026, 9, 2, 21, 0);
      final next = nextReminderOccurrence(now, 20, 0);
      expect(next, DateTime(2026, 9, 3, 20, 0));
    });

    test('恰好等于当前时刻 → 明天触发（不得排已过去的时间）', () {
      final now = DateTime(2026, 9, 2, 20, 0);
      final next = nextReminderOccurrence(now, 20, 0);
      expect(next, DateTime(2026, 9, 3, 20, 0));
    });

    test('月初边界：8 月 31 日 21:00 排 0:05 → 9 月 1 日', () {
      final now = DateTime(2026, 8, 31, 21, 0);
      final next = nextReminderOccurrence(now, 0, 5);
      expect(next, DateTime(2026, 9, 1, 0, 5));
    });
  });
}
