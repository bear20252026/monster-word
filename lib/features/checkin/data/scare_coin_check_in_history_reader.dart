import 'package:word_app/features/checkin/application/check_in_history_reader.dart';
import 'package:word_app/features/scare_coin/application/check_in_calendar.dart';

/// 基于签到日历窄端口（单一事实来源）的签到历史读取适配器。
/// 结构修复步骤4：依赖从上帝端口收窄为 [CheckInCalendar]。
class ScareCoinCheckInHistoryReader implements CheckInHistoryReader {
  ScareCoinCheckInHistoryReader({required this._store});

  final CheckInCalendar _store;

  @override
  Future<Set<String>> getCheckedDates() => _store.checkinDates();

  @override
  Future<int> getStreak() => _store.streak();

  @override
  int get checkInReward => _store.checkInReward;
}
