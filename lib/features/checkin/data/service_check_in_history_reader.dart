import 'package:word_app/features/checkin/data/checkin_service.dart';
import 'package:word_app/features/checkin/application/check_in_history_reader.dart';

/// 基于既有签到服务的历史读取适配器。
class ServiceCheckInHistoryReader implements CheckInHistoryReader {
  ServiceCheckInHistoryReader({required this._service});

  final CheckInService _service;

  @override
  Future<Set<String>> getCheckedDates() => _service.getCheckinDates();

  @override
  Future<int> getStreak() => _service.getStreak();

  @override
  int get checkInReward => _service.checkInReward;
}
