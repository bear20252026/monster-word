// 结算页「三卡」口径：把一局成绩收敛成三件可扫读的事——本次词数 / 正确率 / 用时，
// 答错与最高连击降为一行小字（不占卡位）。
//
// 放在 application 层做纯函数：卡片的数值、称号门槛与文案可单测，widget 只负责画。
// 称号阈值与文案自建（≥90% 才出现），只正向、不贬低低分。
import 'dart:math' as math;

/// 正确率称号门槛：达到才出现称号。
const double completionTitleThreshold = 0.90;

/// 达标称号（自建文案，不使用外部产品文案）。
const String completionTitleFast = '稳准快';

/// 三卡的语义色调（widget 侧映射到皮肤 token）。
enum CompletionCardTone {
  /// 本次词数（主题主色）。
  primary,

  /// 正确率（成就色）。
  achievement,

  /// 用时（中性色）。
  neutral,
}

/// 一张结算卡。
class CompletionCard {
  const CompletionCard({required this.value, required this.label, required this.tone, this.title});

  /// 主数值（如 `+12` / `88%` / `2:17`）。
  final String value;

  /// 卡片标签（如「本次学习」）。
  final String label;

  final CompletionCardTone tone;

  /// 可选称号（仅正确率达标时非空）。
  final String? title;
}

/// 三卡 + 一行小字。
class CompletionCards {
  const CompletionCards({required this.cards, required this.note});

  /// 固定三张卡（顺序：词数 / 正确率 / 用时）。
  final List<CompletionCard> cards;

  /// 小字备注（答错 / 最高连击）；null 表示不显示。
  final String? note;
}

/// 由一局统计生成三卡。
CompletionCards buildCompletionCards({
  required int totalAnswered,
  required int errorCount,
  required double? accuracy,
  required int? durationSeconds,
  int bestCombo = 0,
}) {
  final safeTotal = math.max(0, totalAnswered);
  final safeErrors = math.max(0, errorCount);
  final acc = accuracy == null || accuracy.isNaN || accuracy.isInfinite ? null : accuracy.clamp(0.0, 1.0).toDouble();
  final showTitle = acc != null && acc >= completionTitleThreshold;

  final cards = <CompletionCard>[
    CompletionCard(value: '+$safeTotal', label: '本次学习', tone: CompletionCardTone.primary),
    CompletionCard(
      value: acc == null ? '--' : '${(acc * 100).round()}%',
      label: '正确率',
      tone: CompletionCardTone.achievement,
      title: showTitle ? completionTitleFast : null,
    ),
    CompletionCard(value: formatCompletionDuration(durationSeconds), label: '用时', tone: CompletionCardTone.neutral),
  ];

  final notes = <String>[if (safeErrors > 0) '答错 $safeErrors 个', if (bestCombo > 1) '最高连击 ×$bestCombo'];

  return CompletionCards(cards: cards, note: notes.isEmpty ? null : notes.join(' · '));
}

/// 结算页用时格式：`M:SS`（不足一分钟为 `0:SS`）；无数据为 `--`。
String formatCompletionDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return '--';
  final minutes = seconds ~/ 60;
  final remain = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remain';
}
