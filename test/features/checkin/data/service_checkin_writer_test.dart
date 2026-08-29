import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/checkin/data/service_checkin_writer.dart';
import 'package:word_app/features/checkin/data/checkin_service.dart';

/// 模拟 CheckInService（仅实现写入相关方法）
class FakeCheckInService implements CheckInService {
  bool _checkInResult = true;
  int _streak = 0;
  bool _canCheckIn = true;

  void setCheckInResult(bool value) => _checkInResult = value;
  void setStreak(int value) => _streak = value;
  void setCanCheckIn(bool value) => _canCheckIn = value;

  @override
  Future<bool> checkIn() async {
    if (!_canCheckIn) return false;
    _streak++;
    return _checkInResult;
  }

  @override
  Future<bool> hasCheckedInToday() async => !_canCheckIn;

  @override
  Future<int> getStreakDays() async => _streak;

  @override
  Future<List<DateTime>> getCheckInRecords() async => [];

  @override
  Future<Set<String>> getCheckinDates() async => {};

  @override
  Future<int> getStreak() async => _streak;

  @override
  int get checkInReward => 10;
}

void main() {
  group('ServiceCheckinWriter', () {
    late FakeCheckInService fakeService;
    late ServiceCheckinWriter writer;

    setUp(() {
      fakeService = FakeCheckInService();
      writer = ServiceCheckinWriter(service: fakeService);
    });

    test('checkIn 成功', () async {
      fakeService.setCheckInResult(true);
      fakeService.setCanCheckIn(true);

      final result = await writer.checkIn();
      expect(result, isTrue);
    });

    test('checkIn 今天已签到时返回 false', () async {
      fakeService.setCanCheckIn(false);

      final result = await writer.checkIn();
      expect(result, isFalse);
    });

    test('getStreak 返回连续天数', () async {
      fakeService.setStreak(10);
      expect(await writer.getStreak(), 10);
    });
  });
}
