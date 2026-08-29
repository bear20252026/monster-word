import 'checkin_service.dart';
import '../application/checkin_writer.dart';

/// 基于 CheckInService 的签到写入适配器。
class ServiceCheckinWriter implements CheckinWriter {
  ServiceCheckinWriter({required this._service});

  final CheckInService _service;

  @override
  Future<bool> checkIn() => _service.checkIn();

  @override
  Future<int> getStreak() => _service.getStreak();
}
