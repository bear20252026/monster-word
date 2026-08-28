import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/checkin/domain/checkin_record.dart';

void main() {
  group('CheckinRecord', () {
    test('构造和相等性', () {
      final r1 = CheckinRecord(date: DateTime(2025, 3, 15), reward: 10);
      final r2 = CheckinRecord(date: DateTime(2025, 3, 15), reward: 20);
      final r3 = CheckinRecord(date: DateTime(2025, 3, 16), reward: 10);

      // 同日不同奖励 → 相等（只比较日期）
      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));

      // 不同日期 → 不相等
      expect(r1, isNot(equals(r3)));
    });

    test('isoDate 格式', () {
      final r = CheckinRecord(date: DateTime(2025, 1, 5), reward: 10);
      expect(r.isoDate, '2025-01-05');
    });

    test('isoDate 零填充', () {
      final r = CheckinRecord(date: DateTime(2025, 12, 31), reward: 10);
      expect(r.isoDate, '2025-12-31');
    });
  });
}
