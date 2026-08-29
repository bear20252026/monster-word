import 'package:flutter/material.dart';

import '../../../../core/engine/core_engine.dart' show WordChoicePair;
import '../../../../hooks/responsive.dart';
import '../../../../theme/skin_system.dart';

/// 毛玻璃候选卡片。
///
/// 候选反馈由已计算的布尔值表达，卡片本身不判断正确答案或读写会话状态。
class FormalReviewChoiceCard extends StatelessWidget {
  const FormalReviewChoiceCard({
    super.key,
    required this.pair,
    required this.isCorrect,
    required this.isSelectedWrong,
    required this.showAnswer,
    required this.skin,
    required this.responsive,
    required this.onTap,
  });

  final WordChoicePair pair;
  final bool isCorrect;
  final bool isSelectedWrong;
  final bool showAnswer;
  final ThemeVars skin;
  final AppResponsive responsive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bgColor, borderColor) = switch ((isSelectedWrong, isCorrect && showAnswer)) {
      (true, _) => (skin.quizWrongBg.withValues(alpha: 0.6), skin.quizWrongBg),
      (_, true) => (skin.quizCorrectBg.withValues(alpha: 0.6), skin.quizCorrectBg),
      _ => (skin.glassBg.withValues(alpha: 0.25), skin.glassBorder.withValues(alpha: 0.3)),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(horizontal: 20 * responsive.scale, vertical: 18 * responsive.scale),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Text(
          pair.interpret,
          style: TextStyle(
            fontSize: 16 * responsive.fontScale,
            color: skin.onGlassText1,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
