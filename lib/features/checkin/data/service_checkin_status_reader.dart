import '../../../services/checkin_service.dart';
import '../application/checkin_status_reader.dart';
import '../domain/checkin_status.dart';

/// 基于 CheckInService 的签到状态读取适配器。
class ServiceCheckinStatusReader implements CheckinStatusReader {
  ServiceCheckinStatusReader({required this._service});

  final CheckInService _service;

  @override
  Future<CheckinStatus> getStatus() async {
    final results = await Future.wait([
      _service.hasCheckedInToday(),
      _service.getStreakDays(),
      _service.getCheckInRecords(),
    ]);
    return CheckinStatus(
      todayChecked: results[0] as bool,
      streakDays: results[1] as int,
      totalDays: (results[2] as List<DateTime>).length,
      reward: _service.checkInReward,
    );
  }

  @override
  Future<Set<String>> getCheckinDates() => _service.getCheckinDates();

  @override
  Future<int> getStreakDays() => _service.getStreakDays();

  @override
  Future<bool> hasCheckedInToday() => _service.hasCheckedInToday();
}
