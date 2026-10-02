import 'package:flutter/material.dart';
import 'package:word_app/tokens/design_tokens.dart';

import 'package:word_app/core/engine/core_engine.dart' show WordChoicePair;
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/quiz_feedback_fx.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';

/// 候选卡片：字母徽标 + 释义，按压缩放反馈。
///
/// 体验对齐学习页（P 复习质感升级）：非状态卡带双层浮起阴影；答对时对勾
/// 以 springPop 弹入；答错时温柔下沉（无惩罚感的 dip）。候选反馈由已计算
/// 的布尔值表达，卡片本身不判断正确答案或读写会话状态。
class FormalReviewChoiceCard extends StatefulWidget {
  const FormalReviewChoiceCard({
    super.key,
    required this.pair,
    required this.index,
    required this.isCorrect,
    required this.isSelectedWrong,
    required this.correctRevealed,
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

  /// 本题已答对（反馈驻留窗口内）：正确卡变绿并弹入对勾。
  final bool correctRevealed;
  final bool showAnswer;
  final ThemeVars skin;
  final AppResponsive responsive;
  final VoidCallback onTap;

  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  State<FormalReviewChoiceCard> createState() => _FormalReviewChoiceCardState();
}

class _FormalReviewChoiceCardState extends State<FormalReviewChoiceCard> with TickerProviderStateMixin {
  /// 对勾弹入（答对反馈驻留触发）。
  late final AnimationController _mark = AnimationController(vsync: this, duration: MotionDurations.base);

  /// 答错温柔下沉（错误反馈窗口内，随状态自动复位）。
  late final AnimationController _dip = AnimationController(vsync: this, duration: MotionDurations.slow);

  @override
  void initState() {
    super.initState();
    if (widget.isSelectedWrong) _dip.forward();
  }

  @override
  void didUpdateWidget(covariant FormalReviewChoiceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final correctNow = widget.isCorrect && widget.correctRevealed;
    if (correctNow && !_mark.isAnimating) _mark.forward(from: 0);
    if (widget.isSelectedWrong && !oldWidget.isSelectedWrong) {
      _dip.forward(from: 0);
    } else if (!widget.isSelectedWrong && _dip.isCompleted) {
      _dip.value = 0;
    }
  }

  @override
  void dispose() {
    _mark.dispose();
    _dip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final correctShown = w.isCorrect && (w.correctRevealed || w.showAnswer);
    final (bgColor, borderColor, fgColor) = switch ((w.isSelectedWrong, correctShown)) {
      (true, _) => (w.skin.quizWrongBg.withValues(alpha: AppAlphas.o55), w.skin.quizWrongText, w.skin.quizWrongText),
      (_, true) => (
        w.skin.quizCorrectBg.withValues(alpha: AppAlphas.o55),
        w.skin.quizCorrectText,
        w.skin.quizCorrectText,
      ),
      _ => (
        w.skin.glassBg.withValues(alpha: AppAlphas.o25),
        w.skin.glassBorder.withValues(alpha: AppAlphas.o30),
        w.skin.onGlassText1,
      ),
    };
    final dimmed = w.showAnswer && !w.isCorrect && !w.isSelectedWrong;
    final showMark = correctShown || w.isSelectedWrong;
    final letter = FormalReviewChoiceCard._letters[w.index.clamp(0, FormalReviewChoiceCard._letters.length - 1)];

    Widget card = AnimatedContainer(
      duration: MotionDurations.base,
      curve: Curves.easeOut,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.symmetric(horizontal: 18 * w.responsive.scale, vertical: 16 * w.responsive.scale),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(context.design.radius.md),
        border: Border.all(color: borderColor, width: correctShown || w.isSelectedWrong ? 1.2 : 0.5),
        // 双层浮起阴影对齐学习页选项卡；状态卡（绿/红）以色块表达，不带影
        boxShadow: correctShown || w.isSelectedWrong ? null : MwQuizElevation.shadows,
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: w.skin.onGlassText2.withValues(alpha: dimmed ? AppAlphas.o08 : AppAlphas.o14),
            ),
            child: Text(
              letter,
              style: TextStyle(
                fontSize: AppFontSizes.micro,
                fontWeight: FontWeight.w700,
                color: fgColor.withValues(alpha: dimmed ? AppAlphas.o50 : AppAlphas.o85),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedOpacity(
              duration: MotionDurations.base,
              opacity: dimmed ? 0.45 : 1.0,
              child: Text(
                w.pair.interpret,
                style: TextStyle(
                  fontSize: AppFontSizes.bodyMd * w.responsive.fontScale,
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
            if (correctShown)
              // 对勾弹入：springPop 过冲（学习页同款曲线家族）
              MwCheckIconPop(controller: _mark, icon: Icons.check_circle_rounded, color: fgColor, size: 20)
            else
              Icon(Icons.cancel_rounded, size: 20, color: fgColor),
          ],
        ],
      ),
    );

    if (w.isSelectedWrong) {
      // 温柔下沉：dip 5px 即回 + 轻淡（学习页同款，去惩罚感）
      card = MwDipFeedback(progress: _dip, child: card);
    }

    return ScaleDownOnPress(onTap: widget.onTap, child: card);
  }
}
