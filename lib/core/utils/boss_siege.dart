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

// ───────────────────────────────────────────────────────────────────────────
// Boss 战 v2（M0 最小切片）：触发口径、单局上限、状态机、步数文案。
//
// 全部是纯函数 / 纯常量，不读 Provider、不碰存储，方便把「该不该出现头目」
// 的口径单独锁死；页面协调层只负责取事实并调用这里。
// ───────────────────────────────────────────────────────────────────────────

/// v2 触发阈值：与心情机 worried / 围城 legion 同源，**禁止第二个 40**。
const int bossTriggerDueThreshold = legionDueThreshold;

/// 单局到期词上限（参考 word-atlas 的 `due.slice(0, 120)`）。
///
/// 只截断「这一局装多少」，不改「哪些词是 due」：未入局的词仍是到期状态，
/// 下一局继续。截断放在会话初始化里，**不能**放进队列读取适配器——那里有
/// 「到期为空回退整本队列」的既有语义（其他调用方依赖它）。
const int reviewSessionCap = 120;

/// 本局实际进入的到期词数 = min(dueAtStart, cap)；负数按 0 处理。
int sessionDueCount({required int dueAtStart, int cap = reviewSessionCap}) =>
    dueAtStart <= 0 ? 0 : (dueAtStart > cap ? cap : dueAtStart);

/// Boss 战阶段。
enum BossBattlePhase {
  /// 未触发：无到期词 / 不足阈值 / 加载失败。
  absent,

  /// 已触发，当日首次入场尚未走完（M0 不播动画，可直接视为 active 的前一刻）。
  pendingIntro,

  /// 战斗中：中途剩余数再降也不退出（闩锁）。
  active,

  /// 清完本局：唯一退场路径是 `currentWord == null`。
  victory,
}

/// 开局判定头目是否登场，以及当前处于哪个阶段。
///
/// **只吃开局冻结的事实**：调用方必须传会话初始化时定下的 [total]
/// （= `min(dueAtStart, reviewSessionCap)`），不要拿「当前剩余」来判——
/// 否则答掉一题就可能把头目判没，这正是 v1 的抖动来源。
///
/// [hadDueAtStart] = 开局快照的 `dueWords` 非空。为 false 时整段直接 absent：
/// 队列读取适配器会拿整本队列兜底，若不在这里防住，一本 500 词的词书会被
/// 误判成「大军压境」。
BossBattlePhase resolveBossPhase({
  required bool hadDueAtStart,
  required int total,
  required int done,
  required bool hasWord,
  required bool introPlayedToday,
  int threshold = bossTriggerDueThreshold,
}) {
  if (!hadDueAtStart) return BossBattlePhase.absent;
  if (total < threshold) return BossBattlePhase.absent;
  if (!hasWord) return BossBattlePhase.victory;
  if (done == 0 && !introPlayedToday) return BossBattlePhase.pendingIntro;
  return BossBattlePhase.active;
}

/// 本局还剩几步（0..total，负数按 0）。
int bossRemainingSteps(int done, int total) {
  if (total <= 0) return 0;
  final left = total - done;
  if (left <= 0) return 0;
  return left > total ? total : left;
}

/// 头目行的步数标签：「第 x / N 步 · 还剩 M 步」。
///
/// x = 当前正在走的这一步（done + 1），走完一局时钉在 N 上；
/// [total] <= 0 时返回空串（没有一局可走，不摆进度）。
String bossStepLabel(int done, int total) {
  if (total <= 0) return '';
  final remaining = bossRemainingSteps(done, total);
  final step = done >= total ? total : done + 1;
  return '第 $step / $total 步 · 还剩 $remaining 步';
}

/// 头目行的静态叙述（M0 不做动画，只报事实）。
String bossNarrative({required int remaining}) =>
    remaining > 0 ? '头目亲自堵在门口' : '头目退回雾岭了';

/// 清完一局时头目的退场台词（完成页文案与语音共用）。
///
/// 只在真的答过题（done > 0）且头目登场过时才说得出口；普通复习局仍用
/// [siegeVictoryLine]，不能把「没打过仗」说成「守住城」。
const String bossVictoryLine = '头目退回雾岭了，这一城是你守住的！';

/// 当日首次入场的日期戳（`yyyy-MM-dd`），供 SharedPreferences 节流使用。
String bossDayStamp(DateTime now) {
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}
