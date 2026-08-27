import 'package:flutter/material.dart';

import '../../../../engine/core_engine.dart' show WordChoicePair;
import '../../../../hooks/responsive.dart';
import '../../../../models/bb_word_process.dart';
import '../../../../tokens/design_tokens.dart';
import 'formal_review_choice_card.dart';

/// 单词、音标和发音入口。
class FormalReviewWordPrompt extends StatelessWidget {
  const FormalReviewWordPrompt({super.key, required this.word, required this.audioLoading, required this.onPlayAudio});

  final BBWordProcess word;
  final bool audioLoading;
  final ValueChanged<BBWordProcess> onPlayAudio;

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
              fontSize: 42 * responsive.fontScale,
              fontWeight: FontWeight.w800,
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
            style: TextStyle(fontSize: 14 * responsive.fontScale, color: skin.onGlassText2.withValues(alpha: 0.7)),
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

  final BBWordProcess word;
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
            ...choices.map(
              (choice) => FormalReviewChoiceCard(
                pair: choice,
                isCorrect: choice.word == word.word,
                isSelectedWrong: choice.word == selectedWrongChoice,
                showAnswer: showAnswer,
                skin: skin,
                responsive: responsive,
                onTap: () => onSelectChoice(choice.word),
              ),
            ),
        ],
      ),
    );
  }
}

/// 底部“看答案 / 继续”操作栏。
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
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        onTap: showAnswer ? onContinueWithGoodRating : onRevealAnswer,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              showAnswer ? '继续' : '看答案',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: skin.onGlassText1),
            ),
            const SizedBox(height: 6),
            Container(
              width: 24,
              height: 3,
              decoration: BoxDecoration(
                color: showAnswer ? skin.quizCorrectText : skin.quizWrongText,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
