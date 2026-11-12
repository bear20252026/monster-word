// 肚皮储蓄罐离线计息（蓝图 T2「离开的回报」）——纯函数规则，零依赖。
//
// 口径（产品拍板 2026-11-12）：
// - 离开期间怪兽打瞌守罐，按「昨日学习量」定每小时费率；
// - 离线计时上限 8 小时——多睡不加息，绝不制造「不回来就亏」的焦虑；
// - 不足 1 小时不计息；昨日没学习也有保底 1 币/小时（陪伴不嫌少）；
// - 只有用户点罐才结算入账，不自动发币、不弹催促。
//
// 文案红线与 Boss 战同口径：只陈述事实与陪伴，不指责、不催促、零 emoji
// （belly_interest_test 有黑名单与 emoji 自锁）。

/// 离线计息时长上限（小时）：超过部分不再累计。
const int bellyInterestCapHours = 8;

/// 起计门槛（小时）：离开不足 1 小时不计息。
const int bellyInterestMinHours = 1;

/// 昨日每学 1 词 → 每小时多攒 1 币的换算步长。
const int bellyInterestWordsPerCoin = 1;

/// 每小时保底费率（昨日零学习也有的陪伴底）。
const int bellyInterestBasePerHour = 1;

/// 单次结算封顶（币）：8 小时 × 高费率也不无限膨胀。
const int bellyInterestMaxCoins = 40;

/// 计息结果（纯值对象）。
class BellyInterest {
  const BellyInterest({required this.coins, required this.hours});

  /// 本次可结算的币数；0 = 无可结算。
  final int coins;

  /// 实际计入的整小时数（已按上限截断）。
  final int hours;

  bool get isEmpty => coins <= 0;
}

/// 按离线时长与昨日学习量计息。
///
/// [awayMinutes] 离开分钟数（负数按 0）；[yesterdayWords] 昨日 learn+review 词次
/// （负数按 0）。返回截断后的整小时数与币数；不足起计门槛返回空结果。
BellyInterest bellyInterestFor({required int awayMinutes, required int yesterdayWords}) {
  final minutes = awayMinutes < 0 ? 0 : awayMinutes;
  final words = yesterdayWords < 0 ? 0 : yesterdayWords;
  final hours = minutes ~/ Duration.minutesPerHour;
  if (hours < bellyInterestMinHours) return const BellyInterest(coins: 0, hours: 0);
  final cappedHours = hours > bellyInterestCapHours ? bellyInterestCapHours : hours;
  final perHour = bellyInterestBasePerHour + words ~/ bellyInterestWordsPerCoin;
  final coins = (cappedHours * perHour).clamp(0, bellyInterestMaxCoins);
  return BellyInterest(coins: coins, hours: cappedHours);
}

/// 罐边提示（有可结算时）：只说「攒了多少」，不说「你多久没来」。
String bellyInterestHint(int coins) => '肚皮罐攒了 $coins 枚 · 点罐收下';

/// 结算台词（探头气泡）：陪伴口径，固定单句不走台词引擎预算。
const String bellyInterestSettledLine = '你不在的时候，我帮你守着金币。';

/// 空罐点击台词：不催促、不卖惨，给一个正向的小约定。
const String bellyInterestEmptyLine = '罐子空空的。今天学几个词，我就帮你攒起来。';
