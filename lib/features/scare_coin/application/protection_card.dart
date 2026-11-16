// 断签保护卡窄端口（结构修复步骤4，2026-11-16）。
//
// 从上帝端口 ScareCoinStore 拆出的「保护卡」能力组。兑换/回家礼等只需保护卡
// 能力的消费方依赖本窄端口。
abstract interface class ProtectionCard {
  /// 持有上限（囤积贬值，连击才有含金量）。
  int get protectionCap;

  /// 库存（耗材；不占装备架、不计 redeemedBadge）。
  Future<int> protectionCount();

  /// 发放保护卡（每月免费 1 张／兑换），返回发放后库存；
  /// 库存已满抛 StateError——调用方（兑换扣币路径）依赖该抛错触发补偿退款。
  Future<int> addProtection({required int count, required String reason});
}
