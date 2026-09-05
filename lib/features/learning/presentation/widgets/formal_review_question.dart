import 'package:flutter/material.dart';

import 'package:word_app/core/engine/core_engine.dart' show WordChoicePair;
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/models/mw_word_process.dart';
import 'package:word_app/theme/skin_system.dart';
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
              fontSize: 44 * responsive.fontScale,
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
                    color: skin.glassBg.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '美',
                    style: TextStyle(
                      fontSize: 12 * responsive.fontScale,
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
                  style: TextStyle(fontSize: 15 * responsive.fontScale, color: skin.onGlassText2),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '先回想词义再选择，想不起来「看答案」',
            style: TextStyle(
              fontSize: 13 * responsive.fontScale,
              fontStyle: FontStyle.italic,
              color: skin.onGlassText2.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// 正式复习的四选一候选区。
class FormalReviewChoiceGrid extends StatelessWidget {
  const FormalReviewChoiceGrid({
    super.key,
    required this.word,
    required this.choices,
    required this.selectedWrongChoice,
    required this.showAnswer,
    required this.onSelectChoice,
  });

  final MwWordProcess word;
  final List<WordChoicePair> choices;
  final String? selectedWrongChoice;
  final bool showAnswer;
  final ValueChanged<String> onSelectChoice;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final responsive = context.responsive;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.horizontalPadding),
      child: Column(
        children: [
          const SizedBox(height: 8),
          if (choices.isNotEmpty)
            ...choices.asMap().entries.map(
              (entry) => FormalReviewChoiceCard(
                pair: entry.value,
                index: entry.key,
                isCorrect: entry.value.word == word.word,
                isSelectedWrong: entry.value.word == selectedWrongChoice,
                showAnswer: showAnswer,
                skin: skin,
                responsive: responsive,
                onTap: () => onSelectChoice(entry.value.word),
              ),
            ),
        ],
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
              side: BorderSide(color: showAnswer ? skin.accent : skin.onGlassText2.withValues(alpha: 0.5)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                showAnswer ? Icons.arrow_forward_rounded : Icons.visibility_outlined,
                size: 19,
                color: showAnswer ? Colors.white : skin.onGlassText1,
              ),
              const SizedBox(width: 6),
              Text(
                showAnswer ? '继续' : '看答案',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: showAnswer ? Colors.white : skin.onGlassText1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
