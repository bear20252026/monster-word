import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/checkin/domain/checkin_status.dart';

void main() {
  group('CheckinStatus', () {
    test('构造和字段访问', () {
      const status = CheckinStatus(
        todayChecked: true,
        streakDays: 7,
        totalDays: 30,
        reward: 10,
      );

      expect(status.todayChecked, isTrue);
      expect(status.streakDays, 7);
      expect(status.totalDays, 30);
      expect(status.reward, 10);
    });

    test('空状态', () {
      const status = CheckinStatus.empty();

      expect(status.todayChecked, isFalse);
      expect(status.streakDays, 0);
      expect(status.totalDays, 0);
      expect(status.reward, 0);
    });
  });
}
