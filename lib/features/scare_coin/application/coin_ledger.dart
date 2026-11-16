// 尖叫币账本窄端口（结构修复步骤4，2026-11-16）。
//
// 从上帝端口 ScareCoinStore 拆出的「账本」能力组：余额/流水/发币/幂等发币。
// 只需发币或读余额的消费方（LearningRewardService/DailyMissionRewardService/
// 展示余额的 widget）依赖本窄端口，不再被迫看到签到/保护卡/答题奖励全套。
import 'package:word_app/models/scare_coin_entry.dart';

abstract interface class CoinLedger {
  Future<int> balance();

  Future<List<ScareCoinEntry>> history();

  Future<int> grant({required int delta, required String reason});

  /// 幂等发币：同一 [eventKey] 全局只发一次（返回新余额；已发过返回 null）。
  Future<int?> grantOnce({required int delta, required String reason, required String eventKey});
}
