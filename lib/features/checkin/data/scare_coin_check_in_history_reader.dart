import 'package:word_app/features/checkin/application/check_in_history_reader.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';

/// 基于尖叫币账本（单一事实来源）的签到历史读取适配器。
class ScareCoinCheckInHistoryReader implements CheckInHistoryReader {
  ScareCoinCheckInHistoryReader({required this._store});

  final ScareCoinStore _store;

  @override
  Future<Set<String>> getCheckedDates() => _store.checkinDates();

  @override
  Future<int> getStreak() => _store.streak();

  @override
  int get checkInReward => _store.checkInReward;
}
