// 由 Claude 团队生成 | Monster Word App

// L2 收口回归：date_format_utils 紧凑时间串解析（REG-AUDIT-L2）
//
// 句库页与笔记区此前各自手写 substring 解析，已收口为 lib/utils/date_format_utils.dart
// 两个顶级函数。本测试锁定降级行为：长度不足不抛异常，分别返回空串/原文。

import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/utils/date_format_utils.dart';

void main() {
  group('formatMonthDay（yyyyMMdd → MM/dd）', () {
    test('正常 8 位串解析为 MM/dd', () {
      expect(formatMonthDay('20260903'), '09/03');
    });

    test('长度不足 8 位返回空串', () {
      expect(formatMonthDay('2026'), '');
      expect(formatMonthDay('2026090'), '');
      expect(formatMonthDay(''), '');
    });

    test('超长串只取月日段', () {
      expect(formatMonthDay('20260903120000'), '09/03');
    });
  });

  group('formatCompactDateTime（yyyyMMddHHmmss → yyyy-MM-dd HH:mm）', () {
    test('正常 14 位串解析为 yyyy-MM-dd HH:mm', () {
      expect(formatCompactDateTime('20260903143025'), '2026-09-03 14:30');
    });

    test('长度不足 14 位原样返回', () {
      expect(formatCompactDateTime('20260903'), '20260903');
      expect(formatCompactDateTime('2026090314'), '2026090314');
      expect(formatCompactDateTime(''), '');
    });

    test('超长串只截取到分钟', () {
      expect(formatCompactDateTime('20260903143025123'), '2026-09-03 14:30');
    });

    test('REG-AUDIT（I31）: ISO8601 新格式与存量紧凑串显示一致', () async {
      // WordNote._now 2026-09 审计批次起写 ISO8601；旧笔记仍是紧凑串。
      // 修复前 ISO 串被按 14 位 substring 切成乱码。
      expect(formatCompactDateTime('2026-09-03T14:30:25.000'), '2026-09-03 14:30');
      expect(formatCompactDateTime('2026-09-03T14:30:25'), '2026-09-03 14:30');
      // 带时区后缀的 ISO 串同样正确归一化显示
      expect(formatCompactDateTime('2026-09-03T06:30:25.000Z'), isNot(contains('T')), reason: '不残留 ISO 痕迹');
      expect(formatCompactDateTime('2026-09-03T06:30:25.000Z').length, 16, reason: 'yyyy-MM-dd HH:mm 定长');
      // 两种格式在同页混排时展示口径一致（同一时刻）
      expect(formatCompactDateTime('20260903143025'), formatCompactDateTime('2026-09-03T14:30:25'));
      // 非 ISO 的含 '-' 串解析失败时按原文降级，不抛异常
      expect(formatCompactDateTime('not-a-date'), 'not-a-date');
    });
  });
}
