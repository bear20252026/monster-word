import '../domain/scare_coin_entry.dart';

/// 尖叫币功能域的读写应用端口。
///
/// 尖叫币账本与签到历史保持独立事实模型；本端口不依赖学习、复习或账号状态。
abstract interface class ScareCoinStore {
  int get checkInReward;

  Future<int> balance();

  Future<Set<String>> checkinDates();

  Future<int> streak();

  Future<List<ScareCoinEntry>> history();

  Future<String> lastCheckInDate();

  bool isSameDay(String isoDate, DateTime time);

  Future<int?> checkIn();

  Future<int> grant({required int delta, required String reason});
}
