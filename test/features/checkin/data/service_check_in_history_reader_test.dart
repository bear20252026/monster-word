import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/checkin/data/service_check_in_history_reader.dart';
import 'package:word_app/features/checkin/data/checkin_service.dart';

void main() {
  test('reads history values and reward through the existing service', () async {
    final service = _FakeCheckInService();
    final reader = ServiceCheckInHistoryReader(service: service);

    expect(await reader.getCheckedDates(), {'2026-08-28'});
    expect(await reader.getStreak(), 3);
    expect(reader.checkInReward, 10);
    expect(service.calls, ['dates', 'streak']);
  });
}

class _FakeCheckInService implements CheckInService {
  final calls = <String>[];

  @override
  int get checkInReward => 10;

  @override
  Future<bool> checkIn() async => true;

  @override
  Future<List<DateTime>> getCheckInRecords() async => const [];

  @override
  Future<Set<String>> getCheckinDates() async {
    calls.add('dates');
    return {'2026-08-28'};
  }

  @override
  Future<int> getStreak() async {
    calls.add('streak');
    return 3;
  }

  @override
  Future<int> getStreakDays() async => 3;

  @override
  Future<bool> hasCheckedInToday() async => true;
}
