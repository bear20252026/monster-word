import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/checkin/data/service_checkin_status_reader.dart';
import 'package:word_app/features/checkin/data/checkin_service.dart';

/// 模拟 CheckInService（仅实现读取相关方法）
class FakeCheckInService implements CheckInService {
  bool _hasCheckedInToday = false;
  int _streakDays = 5;
  List<DateTime> _records = [];
  int _reward = 10;

  void setCheckedInToday(bool value) => _hasCheckedInToday = value;
  void setStreakDays(int value) => _streakDays = value;
  void setRecords(List<DateTime> value) => _records = value;
  void setReward(int value) => _reward = value;

  @override
  Future<bool> checkIn() async => false;

  @override
  Future<bool> hasCheckedInToday() async => _hasCheckedInToday;

  @override
  Future<int> getStreakDays() async => _streakDays;

  @override
  Future<List<DateTime>> getCheckInRecords() async => _records;

  @override
  Future<Set<String>> getCheckinDates() async {
    return _records.map((d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}').toSet();
  }

  @override
  Future<int> getStreak() async => _streakDays;

  @override
  int get checkInReward => _reward;
}

void main() {
  group('ServiceCheckinStatusReader', () {
    late FakeCheckInService fakeService;
    late ServiceCheckinStatusReader reader;

    setUp(() {
      fakeService = FakeCheckInService();
      reader = ServiceCheckinStatusReader(service: fakeService);
    });

    test('getStatus 返回正确状态', () async {
      fakeService.setCheckedInToday(true);
      fakeService.setStreakDays(7);
      fakeService.setRecords([
        DateTime(2025, 3, 1),
        DateTime(2025, 3, 2),
        DateTime(2025, 3, 3),
      ]);
      fakeService.setReward(10);

      final status = await reader.getStatus();

      expect(status.todayChecked, isTrue);
      expect(status.streakDays, 7);
      expect(status.totalDays, 3);
      expect(status.reward, 10);
    });

    test('getCheckinDates 委托到 service', () async {
      fakeService.setRecords([
        DateTime(2025, 3, 1),
        DateTime(2025, 3, 5),
      ]);

      final dates = await reader.getCheckinDates();
      expect(dates, contains('2025-03-01'));
      expect(dates, contains('2025-03-05'));
      expect(dates.length, 2);
    });

    test('hasCheckedInToday 委托到 service', () async {
      fakeService.setCheckedInToday(false);
      expect(await reader.hasCheckedInToday(), isFalse);

      fakeService.setCheckedInToday(true);
      expect(await reader.hasCheckedInToday(), isTrue);
    });

    test('getStreakDays 委托到 service', () async {
      fakeService.setStreakDays(15);
      expect(await reader.getStreakDays(), 15);
    });
  });
}
