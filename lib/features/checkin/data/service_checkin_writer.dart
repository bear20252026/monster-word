import 'package:word_app/features/checkin/data/checkin_service.dart';
import 'package:word_app/features/checkin/application/checkin_writer.dart';

/// 基于 CheckInService 的签到写入适配器。
class ServiceCheckinWriter implements CheckinWriter {
  ServiceCheckinWriter({required this._service});

  final CheckInService _service;

  @override
  Future<bool> checkIn() => _service.checkIn();

  @override
  Future<int> getStreak() => _service.getStreak();
}
