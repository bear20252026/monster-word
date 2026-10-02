import 'package:flutter/material.dart';

import 'package:word_app/core/engine/core_engine.dart' show WordChoicePair;
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/models/mw_word_process.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/effect_palette.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/box_reveal.dart';
import 'package:word_app/widgets/confetti.dart';
import 'package:word_app/features/learning/presentation/widgets/formal_review_choice_card.dart';

/// 单词、音标和发音入口。
class FormalReviewWordPrompt extends StatelessWidget {
  const FormalReviewWordPrompt({super.key, required this.word, required this.audioLoading, required this.onPlayAudio});

  final MwWordProcess word;
  final bool audioLoading;
  final ValueChanged<MwWordProcess> onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final responsive = context.responsive;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            word.word,
            style: TextStyle(
              fontFamily: 'Charter',
              fontSize: AppFontSizes.displayMd * responsive.fontScale,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.8,
              color: skin.onGlassText1,
              height: 1.1,
            ),
          ),
          if (word.usPron.isNotEmpty || word.ukPron.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: skin.glassBg.withValues(alpha: AppAlphas.o25),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    '美',
                    style: TextStyle(
                      fontSize: AppFontSizes.micro * responsive.fontScale,
                      color: skin.onGlassText1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => onPlayAudio(word),
                  child: audioLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: skin.onGlassText2),
                        )
                      : Icon(Icons.volume_up_outlined, color: skin.onGlassText2, size: 20),
                ),
                const SizedBox(width: 6),
                Text(
                  '/${word.usPron.isNotEmpty ? word.usPron : word.ukPron}/',
                  style: TextStyle(fontSize: AppFontSizes.bodyXl * responsive.fontScale, color: skin.onGlassText2),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '先回想词义再选择，想不起来「看答案」',
            style: TextStyle(
              fontSize: AppFontSizes.caption * responsive.fontScale,
              fontStyle: FontStyle.italic,
              color: skin.onGlassText2.withValues(alpha: AppAlphas.o70),
            ),
          ),
        ],
      ),
    );
  }
}

/// 正式复习的四选一候选区。
///
/// 体验对齐学习页：选项经 BoxReveal 左侧波次入场（换词重放）；答对瞬间
/// 撒彩带（反馈驻留窗口内）。仍为纯展示组件——状态由布尔快照传入。
class FormalReviewChoiceGrid extends StatefulWidget {
  const FormalReviewChoiceGrid({
    super.key,
    required this.word,
    required this.choices,
    required this.selectedWrongChoice,
    required this.correctRevealed,
    required this.showAnswer,
    required this.onSelectChoice,
  });

  final MwWordProcess word;
  final List<WordChoicePair> choices;
  final String? selectedWrongChoice;

  /// 本题已答对（反馈驻留窗口内）：答对瞬间触发彩带。
  final bool correctRevealed;
  final bool showAnswer;
  final ValueChanged<String> onSelectChoice;

  @override
  State<FormalReviewChoiceGrid> createState() => _FormalReviewChoiceGridState();
}

class _FormalReviewChoiceGridState extends State<FormalReviewChoiceGrid> {
  final ConfettiController _confetti = ConfettiController();

  @override
  void didUpdateWidget(covariant FormalReviewChoiceGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 答对沿触发：反馈驻留开始即撒彩带；换词（新题）自然复位
    if (widget.correctRevealed && !oldWidget.correctRevealed) {
      _confetti.play();
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final responsive = context.responsive;
    final w = widget;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.horizontalPadding),
      child: ConfettiOverlay(
        controller: _confetti,
        particleCount: 30,
        direction: ConfettiDirection.down,
        duration: const Duration(seconds: 2),
        colors: GradientEffects.celebration,
        child: Column(
          children: [
            const SizedBox(height: 8),
            if (w.choices.isNotEmpty)
              ...w.choices.asMap().entries.map(
                (entry) => BoxReveal(
                  // 换词即新 key：每题重新波次入场（学习页同款「页面会话内
                  // 一次」语义在复习中按题重放——题目本身就是新会话）
                  key: ValueKey('${w.word.word}-${entry.key}'),
                  direction: BoxRevealDirection.left,
                  duration: MotionDurations.slow,
                  delay: Duration(milliseconds: 50 * entry.key),
                  reveal: true,
                  child: FormalReviewChoiceCard(
                    pair: entry.value,
                    index: entry.key,
                    isCorrect: entry.value.word == w.word.word,
                    isSelectedWrong: entry.value.word == w.selectedWrongChoice,
                    correctRevealed: w.correctRevealed,
                    showAnswer: w.showAnswer,
                    skin: skin,
                    responsive: responsive,
                    onTap: () => w.onSelectChoice(entry.value.word),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 底部“看答案 / 继续”胶囊操作钮。
class FormalReviewAnswerAction extends StatelessWidget {
  const FormalReviewAnswerAction({
    super.key,
    required this.showAnswer,
    required this.onRevealAnswer,
    required this.onContinueWithGoodRating,
  });

  final bool showAnswer;
  final VoidCallback onRevealAnswer;
  final VoidCallback onContinueWithGoodRating;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final responsive = context.responsive;
    return Padding(
      padding: EdgeInsets.fromLTRB(responsive.horizontalPadding, 8, responsive.horizontalPadding, 20),
      child: GestureDetector(
        onTap: showAnswer ? onContinueWithGoodRating : onRevealAnswer,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: showAnswer ? skin.accent : Colors.transparent,
            shape: StadiumBorder(
              side: BorderSide(color: showAnswer ? skin.accent : skin.onGlassText2.withValues(alpha: AppAlphas.o50)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                showAnswer ? Icons.arrow_forward_rounded : Icons.visibility_outlined,
                size: 19,
                color: showAnswer ? AppColors.white100 : skin.onGlassText1,
              ),
              const SizedBox(width: 6),
              Text(
                showAnswer ? '继续' : '看答案',
                style: TextStyle(
                  fontSize: AppFontSizes.bodyMd,
                  fontWeight: FontWeight.w600,
                  color: showAnswer ? AppColors.white100 : skin.onGlassText1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
