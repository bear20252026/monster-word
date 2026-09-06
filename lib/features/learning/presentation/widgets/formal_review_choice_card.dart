import 'package:flutter/material.dart';

import 'package:word_app/core/engine/core_engine.dart' show WordChoicePair;
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';
import 'package:word_app/tokens/motion_tokens.dart';

/// 候选卡片：字母徽标 + 释义，按压缩放反馈，正误态带图标。
///
/// 候选反馈由已计算的布尔值表达，卡片本身不判断正确答案或读写会话状态。
class FormalReviewChoiceCard extends StatelessWidget {
  const FormalReviewChoiceCard({
    super.key,
    required this.pair,
    required this.index,
    required this.isCorrect,
    required this.isSelectedWrong,
    required this.showAnswer,
    required this.skin,
    required this.responsive,
    required this.onTap,
  });

  final WordChoicePair pair;

  /// 选项序号（0 起），用于展示 A/B/C/D 徽标。
  final int index;
  final bool isCorrect;
  final bool isSelectedWrong;
  final bool showAnswer;
  final ThemeVars skin;
  final AppResponsive responsive;
  final VoidCallback onTap;

  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  Widget build(BuildContext context) {
    final (bgColor, borderColor, fgColor) = switch ((isSelectedWrong, isCorrect && showAnswer)) {
      (true, _) => (skin.quizWrongBg.withValues(alpha: 0.55), skin.quizWrongText, skin.quizWrongText),
      (_, true) => (skin.quizCorrectBg.withValues(alpha: 0.55), skin.quizCorrectText, skin.quizCorrectText),
      _ => (skin.glassBg.withValues(alpha: 0.25), skin.glassBorder.withValues(alpha: 0.3), skin.onGlassText1),
    };
    final dimmed = showAnswer && !isCorrect && !isSelectedWrong;
    final showMark = (isCorrect && showAnswer) || isSelectedWrong;
    final letter = _letters[index.clamp(0, _letters.length - 1)];

    return ScaleDownOnPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: MotionDurations.base,
        curve: Curves.easeOut,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(horizontal: 18 * responsive.scale, vertical: 16 * responsive.scale),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: (isCorrect && showAnswer) || isSelectedWrong ? 1.2 : 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: skin.onGlassText2.withValues(alpha: dimmed ? 0.08 : 0.14),
              ),
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fgColor.withValues(alpha: dimmed ? 0.5 : 0.85),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedOpacity(
                duration: MotionDurations.base,
                opacity: dimmed ? 0.45 : 1.0,
                child: Text(
                  pair.interpret,
                  style: TextStyle(
                    fontSize: 16 * responsive.fontScale,
                    color: fgColor,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (showMark) ...[
              const SizedBox(width: 8),
              Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 20, color: fgColor),
            ],
          ],
        ),
      ),
    );
  }
}
