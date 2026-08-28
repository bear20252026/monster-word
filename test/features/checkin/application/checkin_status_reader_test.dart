import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/checkin/domain/checkin_status.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';

/// 模拟 CheckinStatusReader
class MockCheckinStatusReader implements CheckinStatusReader {
  CheckinStatus _status = const CheckinStatus.empty();
  Set<String> _dates = {};

  void setStatus(CheckinStatus status) => _status = status;
  void setDates(Set<String> dates) => _dates = dates;

  @override
  Future<CheckinStatus> getStatus() async => _status;

  @override
  Future<Set<String>> getCheckinDates() async => _dates;

  @override
  Future<int> getStreakDays() async => _status.streakDays;

  @override
  Future<bool> hasCheckedInToday() async => _status.todayChecked;
}

void main() {
  group('CheckinStatusReader port contract', () {
    late MockCheckinStatusReader reader;

    setUp(() {
      reader = MockCheckinStatusReader();
    });

    test('getStatus 返回当前状态', () async {
      const expected = CheckinStatus(todayChecked: true, streakDays: 5, totalDays: 15, reward: 10);
      reader.setStatus(expected);

      final actual = await reader.getStatus();
      expect(actual.todayChecked, expected.todayChecked);
      expect(actual.streakDays, expected.streakDays);
      expect(actual.totalDays, expected.totalDays);
      expect(actual.reward, expected.reward);
    });

    test('getCheckinDates 返回日期集合', () async {
      reader.setDates({'2025-03-01', '2025-03-02', '2025-03-03'});

      final dates = await reader.getCheckinDates();
      expect(dates.length, 3);
      expect(dates, contains('2025-03-01'));
    });

    test('hasCheckedInToday 反映状态', () async {
      reader.setStatus(const CheckinStatus.empty());
      expect(await reader.hasCheckedInToday(), isFalse);

      reader.setStatus(const CheckinStatus(todayChecked: true, streakDays: 1, totalDays: 1, reward: 10));
      expect(await reader.hasCheckedInToday(), isTrue);
    });

    test('getStreakDays 返回连续天数', () async {
      reader.setStatus(const CheckinStatus(todayChecked: false, streakDays: 12, totalDays: 30, reward: 10));
      expect(await reader.getStreakDays(), 12);
    });
  });
}
