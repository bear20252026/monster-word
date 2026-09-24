// 字惊币账本端口（从 data 层上提，跨 feature 引用走 application）
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

  /// 断签保护卡持有上限（囤积贬值，连击才有含金量）。
  int get protectionCap;

  /// 断签保护卡库存（耗材；不占装备架、不计 redeemedBadge）。
  Future<int> protectionCount();

  /// 发放保护卡（连签奖励／兑换），钳制上限后返回当前库存。
  Future<int> addProtection({required int count, required String reason});

  /// 答对即时奖励上限（＋1／次，每日封顶，防刷）。
  int get answerRewardDailyCap;

  /// 答对即时奖励：未达日上限发＋1 并返回 1，否则返回 0（可重入）。
  Future<int> grantAnswerReward();
}
