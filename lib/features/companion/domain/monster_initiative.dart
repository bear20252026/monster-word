// 怪兽的「主动发起」规则（companion 域，纯 Dart 零依赖）。
//
// 借的是 N.E.K.O 的**主动**（它会先来找你），**不借**它的大模型驱动器：
// 那个需要联网、需要 API key、离线即废。对背单词 App 来说，主动性完全可以
// 用规则表达，而且规则版有三件大模型做不到的好处：零延迟、可预测、可断言。
//
// 产品红线（业主定稿的定位「一只记得你、与你共同完成词汇学习的小怪兽」）：
// - **催学习只能用事实**（「有 24 个词到期了」），不许预测「你快忘了」。
// - **久别重逢只欢迎，不催**（7 天没来先让它高兴，别第一句话就要作业）。
// - **宁可不说话，也别硬凑**：没有值得说的就返回 null。

/// 它主动想做的事。
enum MonsterInitiative {
  /// 提议去复习（有积压）。
  proposeReview,

  /// 提议去签到（仪式断了）。
  proposeCheckin,

  /// 提议改成「三词小组」（连续困难，降低继续的阻力）。
  proposeThreeWordGroup,

  /// 只欢迎回来（久别重逢，不提任务）。
  welcomeBack,
}

/// 判定输入：全部是**已发生的事实**，不含任何预测。
class MonsterInitiativeInput {
  const MonsterInitiativeInput({
    this.dueCount = 0,
    this.daysSinceLastCheckin = 0,
    this.daysSinceLastVisit = 0,
    this.studiedToday = false,
    this.consecutiveWrong = 0,
  });

  /// 已到期的词数。
  final int dueCount;

  /// 距上次签到天数（从未签到按 0 处理，不催新用户）。
  final int daysSinceLastCheckin;

  /// 距上次打开 App 的天数。
  final int daysSinceLastVisit;

  /// 今天是否已经开始学过（学过就不再催复习）。
  final bool studiedToday;

  /// 当前连续答错次数。
  final int consecutiveWrong;
}

/// 一次主动发起的结果。
class MonsterInitiativeDecision {
  const MonsterInitiativeDecision(this.initiative, this.reason);

  final MonsterInitiative initiative;

  /// 判定理由（进埋点/日志用；也方便测试锚定「为什么是这条」）。
  final String reason;
}

/// 阈值（集中放这里，方便产品调；测试也锚这些常量而不是魔数）。
class MonsterInitiativeThresholds {
  const MonsterInitiativeThresholds._();

  /// 到期词达到这个量才值得提「去复习」（少了不值得打断）。
  static const int reviewDueCount = 20;

  /// 签到断这么多天才提。
  static const int checkinGapDays = 2;

  /// 隔这么多天回来 → 只欢迎，不提任何任务。
  static const int welcomeBackGapDays = 7;

  /// 连续答错达到这个数 → 提议三词小组。
  static const int hardStreak = 3;
}

/// 纯函数：此刻它最想说什么（null = 不说）。
///
/// 优先级（高 → 低）：
///   1. 久别重逢 → 只欢迎（**压过一切催办**，包括积压与签到）
///   2. 连续困难 → 三词小组（当场降低阻力，比事后催复习有用）
///   3. 今天还没学且积压够多 → 提议复习
///   4. 签到断了 → 提议签到
MonsterInitiativeDecision? pickInitiative(MonsterInitiativeInput input) {
  if (input.daysSinceLastVisit >= MonsterInitiativeThresholds.welcomeBackGapDays) {
    return const MonsterInitiativeDecision(MonsterInitiative.welcomeBack, '久别重逢优先：先高兴，不提任务');
  }

  if (input.consecutiveWrong >= MonsterInitiativeThresholds.hardStreak) {
    return MonsterInitiativeDecision(
      MonsterInitiative.proposeThreeWordGroup,
      '连续答错 ${input.consecutiveWrong} 次 → 降低阻力比催进度更有用',
    );
  }

  // 已经学过了就别再催 —— 这是「陪伴」与「监工」的分界线。
  if (!input.studiedToday && input.dueCount >= MonsterInitiativeThresholds.reviewDueCount) {
    return MonsterInitiativeDecision(MonsterInitiative.proposeReview, '今天还没开始且有 ${input.dueCount} 个词到期');
  }

  if (input.daysSinceLastCheckin >= MonsterInitiativeThresholds.checkinGapDays) {
    return MonsterInitiativeDecision(MonsterInitiative.proposeCheckin, '签到断了 ${input.daysSinceLastCheckin} 天');
  }

  return null;
}
