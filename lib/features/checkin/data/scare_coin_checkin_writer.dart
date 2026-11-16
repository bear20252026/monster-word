import 'package:word_app/features/checkin/application/checkin_writer.dart';
import 'package:word_app/features/scare_coin/application/check_in_calendar.dart';

/// 基于签到日历窄端口（单一事实来源）的签到写入适配器。
///
/// 结构修复步骤4：依赖从上帝端口 ScareCoinStore 收窄为 [CheckInCalendar]。
/// [CheckInCalendar.checkIn] 返回 null 表示今天已签到（幂等），非 null 为签到后的新余额。
class ScareCoinCheckinWriter implements CheckinWriter {
  ScareCoinCheckinWriter({required this._store});

  final CheckInCalendar _store;

  @override
  Future<bool> checkIn() async => (await _store.checkIn()) != null;

  @override
  Future<int> getStreak() => _store.streak();
}
