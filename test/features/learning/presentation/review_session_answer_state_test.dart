import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/presentation/review_session_answer_state.dart';

void main() {
  group('ReviewSessionAnswerState', () {
    test('正确选择不写入错误反馈，评分推进交由宿主处理', () {
      var notifications = 0;
      final state = ReviewSessionAnswerState(onChanged: () => notifications++);

      final result = state.selectChoice(selectedWord: 'correct', correctWord: 'correct');

      expect(result, ReviewChoiceSelection.correct);
      expect(state.selectedWrongChoice, isNull);
      expect(notifications, 0);
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
    });

    test('答案揭示幂等，题目重置会同时清理答案与错误反馈', () {
      var notifications = 0;
      final state = ReviewSessionAnswerState(onChanged: () => notifications++);

      expect(state.revealAnswer(), isTrue);
      expect(state.revealAnswer(), isFalse);
      state.selectChoice(selectedWord: 'wrong', correctWord: 'correct');
      state.reset();

      expect(state.showAnswer, isFalse);
      expect(state.selectedWrongChoice, isNull);
      expect(notifications, 2);
      state.dispose();
    });
  });
}
