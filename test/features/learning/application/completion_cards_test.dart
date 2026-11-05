// 结算页三卡纯函数：数值口径、称号门槛、时长格式与边界。
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/application/completion_cards.dart';

void main() {
  group('buildCompletionCards', () {
    test('三卡固定顺序：本次学习 / 正确率 / 用时', () {
      final result = buildCompletionCards(totalAnswered: 12, errorCount: 1, accuracy: 0.75, durationSeconds: 137);

      expect(result.cards, hasLength(3));
      expect(result.cards[0].label, '本次学习');
      expect(result.cards[0].value, '+12');
      expect(result.cards[0].tone, CompletionCardTone.primary);
      expect(result.cards[1].label, '正确率');
      expect(result.cards[1].value, '75%');
      expect(result.cards[2].label, '用时');
      expect(result.cards[2].value, '2:17');
      expect(result.cards[2].tone, CompletionCardTone.neutral);
    });

    test('正确率 ≥ 90% 才出现称号，89% 不出现', () {
      final fast = buildCompletionCards(totalAnswered: 10, errorCount: 0, accuracy: 0.9, durationSeconds: 60);
      expect(fast.cards[1].title, completionTitleFast);

      final slow = buildCompletionCards(totalAnswered: 10, errorCount: 2, accuracy: 0.89, durationSeconds: 60);
      expect(slow.cards[1].title, isNull);
    });

    test('无答题记录：正确率为 --、无称号，用时为 --', () {
      final result = buildCompletionCards(totalAnswered: 0, errorCount: 0, accuracy: null, durationSeconds: null);

      expect(result.cards[1].value, '--');
      expect(result.cards[1].title, isNull);
      expect(result.cards[2].value, '--');
      expect(result.note, isNull);
    });

    test('答错与最高连击降为一行小字，无错误与连击时不显示', () {
      final withNote = buildCompletionCards(
        totalAnswered: 10,
        errorCount: 2,
        accuracy: 0.8,
        durationSeconds: 90,
        bestCombo: 5,
      );
      expect(withNote.note, '答错 2 个 · 最高连击 ×5');

      final onlyErrors = buildCompletionCards(totalAnswered: 10, errorCount: 1, accuracy: 0.9, durationSeconds: 90);
      expect(onlyErrors.note, '答错 1 个');

      final clean = buildCompletionCards(totalAnswered: 10, errorCount: 0, accuracy: 1.0, durationSeconds: 90);
      expect(clean.note, isNull);
    });

    test('脏数据兜底：负数与越界正确率被夹紧，不抛错', () {
      final result = buildCompletionCards(totalAnswered: -3, errorCount: -1, accuracy: 1.4, durationSeconds: -5);

      expect(result.cards[0].value, '+0');
      expect(result.cards[1].value, '100%');
      expect(result.cards[2].value, '--');
      expect(result.note, isNull);
    });
  });

  group('formatCompletionDuration', () {
    test('分钟与秒：不足一分钟补 0，超过一小时仍按总分钟计', () {
      expect(formatCompletionDuration(null), '--');
      expect(formatCompletionDuration(0), '--');
      expect(formatCompletionDuration(5), '0:05');
      expect(formatCompletionDuration(59), '0:59');
      expect(formatCompletionDuration(60), '1:00');
      expect(formatCompletionDuration(3725), '62:05');
    });
  });
}
