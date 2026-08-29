import 'package:word_app/models/scare_coin_entry.dart';

/// 尖叫币功能域的读写应用端口（共享 core 契约）。
///
/// 尖叫币账本与签到历史保持独立事实模型；本端口不依赖学习、复习或账号状态。
/// 该契约被 account / checkin 等多个 feature 及 legacy 页面共享，故提升到核心层，
/// 各消费方只依赖本契约，而非 scare_coin 功能域内部。
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
