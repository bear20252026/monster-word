// 「Boss 战复习」围城口径（纯函数，零 Flutter 依赖）。
//
// 叙事：今天到期的词化作围在门口的捣蛋兽，答对一题击退一只，全清 = 守城成功。
// 设计稿见 docs/boss_siege_design.md（PR #126 入库）。
//
// 两条不可动的口径，都在这里收成一处的原因：
//   ① 敌人数量只认**复习会话的 total**（dueWordsFor 从当前词表子集筛），
//      而首页叙事认 `dueCount`（全词书 SQL 聚合，review_schedule_repository.dart）——
//      两者在词表为子集时并不相等，同屏并列会当场穿帮（「12 只敌人 / 进度 3/30」）。
//   ② 击退数 = 会话 `done`。`rate()` 与 `markAsKnown()` 都会让 done +1，
//      所以 HUD 不需要额外的「掉怪」计数器：done 一变就重绘，天然覆盖两条路径。
//
// 世界观红线：捣蛋兽是被「击退回雾岭」，不是被杀死；积压多只表达担心，绝不羞辱。
// 文案禁 emoji（emoji_hygiene_test 对 lib 非注释行零容忍）。

/// 围城档位。阈值与心情机共用一个事实来源（见 [legionDueThreshold]）。
enum SiegeTier {
  /// 一只不剩：守住了。
  cleared,

  /// 零星几只在外头转悠。
  raid,

  /// 成规模围住门口。
  siege,

  /// 大军压境（与 MonsterMood.worried 同阈值）。
  legion,
}

/// 「大军压境」阈值 = 心情机判定 worried 的到期数阈值，两处必须同数。
const int legionDueThreshold = 40;

/// 「围城」起始阈值。
const int siegeDueThreshold = 10;

/// 敌列一屏最多画几只（超出只加「+N」，避免 40+ 只图标把答题区挤没）。
const int maxVisibleMarauders = 12;

/// 剩余敌人（= 会话未答数）→ 围城档位。
SiegeTier siegeTierFor(int remaining) {
  if (remaining <= 0) return SiegeTier.cleared;
  if (remaining < siegeDueThreshold) return SiegeTier.raid;
  if (remaining < legionDueThreshold) return SiegeTier.siege;
  return SiegeTier.legion;
}

/// 档位 + 剩余数 → 门口那句陈述（只报事实，不评价用户）。
String siegeNarrative(SiegeTier tier, int remaining) => switch (tier) {
  SiegeTier.cleared => '门口一只捣蛋兽都没有了',
  SiegeTier.raid => '门外还有 $remaining 只在转悠',
  SiegeTier.siege => '门口围着 $remaining 只捣蛋兽',
  SiegeTier.legion => '大军压境：$remaining 只捣蛋兽堵在门口',
};

/// 敌列里该画几只实体图标，以及溢出数量（`+N`）。
///
/// [remaining] 为 0 时返回 0 只（守城成功的空场）；负数按 0 处理。
({int visible, int overflow}) marauderBadgeCounts(int remaining) {
  final left = remaining <= 0 ? 0 : remaining;
  return (
    visible: left > maxVisibleMarauders ? maxVisibleMarauders : left,
    overflow: left > maxVisibleMarauders ? left - maxVisibleMarauders : 0,
  );
}

/// 守城成功那一句（完成页发声音 + 文案共用）。
///
/// 只在剩余为 0 时才说得出这句话——它是事实陈述，不是「新纪录」这类无法验证的评价；
/// 一题都没答（done==0，今天本来没有到期词）时连这句都不许出现。
const String siegeVictoryLine = '门口一只都没有了，这一城是你守住的！';

/// 今天没有到期词时的空场陈述（与 [siegeVictoryLine] 区分：没打过仗不能说守住了）。
const String siegeQuietLine = '今天没有到期的单词，门口很安静';
