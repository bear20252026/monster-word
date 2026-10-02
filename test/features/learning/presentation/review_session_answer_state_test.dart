import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/presentation/review_session_answer_state.dart';

void main() {
  group('ReviewSessionAnswerState', () {
    test('正确选择进入反馈驻留：置位通知宿主，驻留结束回调宿主推进', () async {
      var notifications = 0;
      var elapsed = 0;
      final state = ReviewSessionAnswerState(
        onChanged: () => notifications++,
        onCorrectFeedbackElapsed: () => elapsed++,
        correctFeedback: const Duration(milliseconds: 1),
      );

      final result = state.selectChoice(selectedWord: 'correct', correctWord: 'correct');

      expect(result, ReviewChoiceSelection.correct);
      expect(state.selectedWrongChoice, isNull);
      expect(state.correctRevealed, isTrue, reason: '答对即进入反馈驻留（对勾/彩带窗口）');
      expect(notifications, 1, reason: '驻留开始通知宿主刷新展示');
      expect(elapsed, 0, reason: '评分推进必须等驻留结束，不得答对即切题');

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(elapsed, 1, reason: '驻留结束回调宿主推进评分');
      // 驻留结束后仍保持答对态，由宿主 reset（题目推进）清理
      expect(state.correctRevealed, isTrue);
      state.dispose();
    });

    test('反馈驻留期内重复选择被忽略（防连点/误触他项）', () {
      var notifications = 0;
      var elapsed = 0;
      final state = ReviewSessionAnswerState(
        onChanged: () => notifications++,
        onCorrectFeedbackElapsed: () => elapsed++,
        correctFeedback: const Duration(milliseconds: 50),
      );

      expect(state.selectChoice(selectedWord: 'correct', correctWord: 'correct'), ReviewChoiceSelection.correct);
      expect(state.selectChoice(selectedWord: 'other', correctWord: 'correct'), ReviewChoiceSelection.correct);
      expect(state.selectChoice(selectedWord: 'correct', correctWord: 'correct'), ReviewChoiceSelection.correct);

      expect(state.selectedWrongChoice, isNull, reason: '驻留期内不写错误反馈');
      expect(state.correctRevealed, isTrue);
      expect(elapsed, 0, reason: '重复选择不得重置或加速驻留计时');
      state.dispose();
    });

    test('错误选择在反馈窗口内可见，并在窗口结束后清理', () async {
      final completion = Completer<void>();
      var notifications = 0;
      final state = ReviewSessionAnswerState(
        onChanged: () {
          notifications++;
          if (notifications == 2 && !completion.isCompleted) completion.complete();
        },
        wrongChoiceFeedback: const Duration(milliseconds: 1),
      );

      final result = state.selectChoice(selectedWord: 'wrong', correctWord: 'correct');
      expect(result, ReviewChoiceSelection.wrong);
      expect(state.selectedWrongChoice, 'wrong');
      expect(state.isWrongChoiceSelected('wrong'), isTrue);

      await completion.future;
      expect(state.selectedWrongChoice, isNull);
      expect(state.isWrongChoiceSelected('wrong'), isFalse);
      state.dispose();
    });

    test('答案揭示幂等，题目重置会同时清理答案、错误反馈与答对驻留', () {
      var notifications = 0;
      final state = ReviewSessionAnswerState(onChanged: () => notifications++);

      expect(state.revealAnswer(), isTrue);
      expect(state.revealAnswer(), isFalse);
      state.selectChoice(selectedWord: 'wrong', correctWord: 'correct');
      state.reset();

      expect(state.showAnswer, isFalse);
      expect(state.selectedWrongChoice, isNull);
      expect(state.correctRevealed, isFalse, reason: '题目推进清理答对驻留');
      expect(notifications, 2);
      state.dispose();
    });
  });
}
