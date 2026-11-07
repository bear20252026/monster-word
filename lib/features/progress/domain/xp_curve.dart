// M3：XP 与等级的纯函数口径。
//
// 只有这里定义曲线，UI 和存储都复用它：
//   - 答对 1 词 +2 XP，完成一局 +10 XP（学习 / 复习同计）；
//   - 每级所需 = 100 × 当前等级（Lv1→2 = 100，Lv2→3 = 200，…）；
//   - 老用户从 0 起算（Lv1），不做任何回填。

const int xpPerCorrectAnswer = 2;
const int xpPerCompletedSession = 10;
const int _xpStep = 100;

/// 一局会话可得 XP：答对数 × 2 + 完成奖励 10。
///
/// `completed` 只有在真的答过题时才该为 true（调用方传入 answered > 0）。
int xpForSession({required int correct, required bool completed}) {
  final safeCorrect = correct < 0 ? 0 : correct;
  return safeCorrect * xpPerCorrectAnswer + (completed ? xpPerCompletedSession : 0);
}

/// 从 [level] 升到下一级所需的 XP（100 × level）。
int xpRequiredForLevel(int level) => _xpStep * (level < 1 ? 1 : level);

/// 到达 [level] 所需的累计 XP（Lv1 = 0，Lv2 = 100，Lv3 = 300，…）。
int xpThresholdForLevel(int level) {
  final n = level < 1 ? 1 : level;
  return _xpStep * (n - 1) * n ~/ 2;
}

/// 累计 XP → 等级（从 Lv1 起）。达到阈值即升级，不设上限。
int levelForXp(int totalXp) {
  final xp = totalXp < 0 ? 0 : totalXp;
  // 每级门槛递增 100 ⇒ 等级随 √(XP) 增长，循环次数与等级同阶；
  // 门槛严格递增，xp 有限时必然收敛。
  var level = 1;
  while (xp >= xpThresholdForLevel(level + 1)) {
    level++;
  }
  return level;
}

/// 某累计 XP 对应的完整快照（等级 / 本级进度 / 距下一级还差多少）。
class XpSnapshot {
  const XpSnapshot({
    required this.totalXp,
    required this.level,
    required this.xpIntoLevel,
    required this.xpToNextLevel,
  });

  final int totalXp;
  final int level;
  final int xpIntoLevel;
  final int xpToNextLevel;

  static const XpSnapshot zero = XpSnapshot(totalXp: 0, level: 1, xpIntoLevel: 0, xpToNextLevel: _xpStep);

  factory XpSnapshot.fromTotal(int totalXp) {
    final xp = totalXp < 0 ? 0 : totalXp;
    final level = levelForXp(xp);
    final into = xp - xpThresholdForLevel(level);
    return XpSnapshot(totalXp: xp, level: level, xpIntoLevel: into, xpToNextLevel: xpRequiredForLevel(level) - into);
  }
}
