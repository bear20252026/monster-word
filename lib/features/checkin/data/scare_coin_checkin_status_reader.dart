import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/checkin/domain/checkin_status.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';

/// 基于尖叫币账本（单一事实来源）的签到状态读取适配器。
///
/// 签到日期/连签天数全部读 [ScareCoinStore]（与签到日历同一份事实），
/// 不再维护第二套签到持久化。
class ScareCoinCheckinStatusReader implements CheckinStatusReader {
  ScareCoinCheckinStatusReader({required this._store});

  final ScareCoinStore _store;

  @override
  Future<CheckinStatus> getStatus() async {
    final results = await Future.wait([hasCheckedInToday(), getStreakDays(), _store.checkinDates()]);
    return CheckinStatus(
      todayChecked: results[0] as bool,
      streakDays: results[1] as int,
      totalDays: (results[2] as Set<String>).length,
      reward: _store.checkInReward,
    );
  }

  @override
  Future<Set<String>> getCheckinDates() => _store.checkinDates();

  @override
  Future<int> getStreakDays() => _store.streak();

  @override
  Future<bool> hasCheckedInToday() async => _store.isSameDay(await _store.lastCheckInDate(), DateTime.now());
}
