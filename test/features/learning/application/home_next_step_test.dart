// 首页主卡「下一步」口径：三态各只有一句动作 + 一个时长预期。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/learning/application/home_next_step.dart';

void main() {
  group('首页下一步口径', () {
    test('今天没开始、也没有到期：开第一组，时长按 20 秒/新词', () {
      final step = resolveHomeNextStep(goal: 10, learned: 0, due: 0);

      expect(step.action, HomeNextAction.learnFirst);
      expect(step.headline, '还差 10 个词');
      expect(step.ctaLabel, '开始今天的第一组');
      expect(step.estimatedMinutes, 4, reason: '200 秒向上取整');
      expect(step.title, '还差 10 个词 · 约 4 分钟');
      expect(step.primaryIsReview, isFalse);
      expect(step.secondaryLabel, isNull);
    });

    test('有到期词：主按钮先复习，时长按 14 秒/词，并留「继续学新词」文字链', () {
      final step = resolveHomeNextStep(goal: 10, learned: 0, due: 5);

      expect(step.action, HomeNextAction.reviewDue);
      expect(step.headline, '先救回 5 个到期词');
      expect(step.ctaLabel, '先救回 5 个到期词');
      expect(step.estimatedMinutes, 2, reason: '70 秒向上取整');
      expect(step.primaryIsReview, isTrue);
      expect(step.secondaryLabel, '继续学新词');
    });

    test('到期词很多时只按到期数估时，不把新词重复计入', () {
      final step = resolveHomeNextStep(goal: 10, learned: 0, due: 40);

      expect(step.action, HomeNextAction.reviewDue);
      expect(step.estimatedMinutes, 10, reason: '560 秒向上取整');
    });

    test('已学一部分、无到期：继续今天的学习', () {
      final step = resolveHomeNextStep(goal: 10, learned: 3, due: 0);

      expect(step.action, HomeNextAction.continueLearning);
      expect(step.headline, '还差 7 个词');
      expect(step.ctaLabel, '继续今天的学习');
      expect(step.estimatedMinutes, 3, reason: '140 秒向上取整');
    });

    test('今日达标：只正向，给一组巩固，不出现扣分/清零语义', () {
      final step = resolveHomeNextStep(goal: 10, learned: 10, due: 0);

      expect(step.action, HomeNextAction.extraPractice);
      expect(step.headline, '今日目标已完成');
      expect(step.ctaLabel, '再练 $homeExtraPracticeCount 个巩固');
      expect(step.estimatedMinutes, 2, reason: '100 秒向上取整');
      expect(step.secondaryLabel, isNull);
    });

    test('负数/零目标不产生负时长或负剩量', () {
      final step = resolveHomeNextStep(goal: 0, learned: 3, due: 0);

      expect(step.estimatedMinutes, 0);
      expect(step.title, contains('0 个词'));
    });
  });
}
