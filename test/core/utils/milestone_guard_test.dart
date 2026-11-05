// MilestoneGuard 纯函数：跨档判定、不跨档、多档连跨取最大、负向不庆祝。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/milestone_guard.dart';

void main() {
  group('MilestoneGuard.crossedMilestone', () {
    test('正向跨档：返回跨越的最大档位', () {
      expect(MilestoneGuard.crossedMilestone(99, 100), 100);
      expect(MilestoneGuard.crossedMilestone(420, 520), 500);
      expect(MilestoneGuard.crossedMilestone(980, 1000), 1000);
    });

    test('多档连跨：只返回最大档（一次庆祝）', () {
      expect(MilestoneGuard.crossedMilestone(480, 1200), 1000);
      expect(MilestoneGuard.crossedMilestone(90, 5100), 5000);
    });

    test('未跨档：null', () {
      expect(MilestoneGuard.crossedMilestone(50, 99), isNull);
      expect(MilestoneGuard.crossedMilestone(100, 499), isNull, reason: '已在档上，不算新跨');
      expect(MilestoneGuard.crossedMilestone(0, 0), isNull);
    });

    test('负向变动（消费）：不庆祝', () {
      expect(MilestoneGuard.crossedMilestone(1200, 800), isNull);
      expect(MilestoneGuard.crossedMilestone(100, 50), isNull);
    });
  });

  group('MilestoneGuard.crossedThreshold（通用档位）', () {
    test('连胜档位可复用同一判定', () {
      expect(MilestoneGuard.crossedThreshold(6, 7, MilestoneGuard.streakThresholds), 7);
      expect(MilestoneGuard.crossedThreshold(6, 60, MilestoneGuard.streakThresholds), 50);
      expect(MilestoneGuard.crossedThreshold(50, 80, MilestoneGuard.streakThresholds), isNull);
      expect(MilestoneGuard.crossedThreshold(14, 1, MilestoneGuard.streakThresholds), isNull);
    });

    test('空档位表与未跨档均返回 null', () {
      expect(MilestoneGuard.crossedThreshold(0, 999, const []), isNull);
      expect(MilestoneGuard.crossedThreshold(0, 5, MilestoneGuard.streakThresholds), isNull);
    });
  });
}
