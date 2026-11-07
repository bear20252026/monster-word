import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/progress/domain/xp_curve.dart';

void main() {
  group('xpForSession', () {
    test('答对 +2、完成一局 +10', () {
      expect(xpForSession(correct: 5, completed: true), 5 * 2 + 10);
      expect(xpForSession(correct: 0, completed: true), 10);
    });

    test('未完成不给完成奖励', () {
      expect(xpForSession(correct: 3, completed: false), 6);
      expect(xpForSession(correct: 0, completed: false), 0);
    });

    test('负数按 0 处理，不会倒扣', () {
      expect(xpForSession(correct: -4, completed: true), 10);
    });
  });

  group('等级曲线', () {
    test('每级所需 = 100 × 当前等级', () {
      expect(xpRequiredForLevel(1), 100);
      expect(xpRequiredForLevel(2), 200);
      expect(xpRequiredForLevel(3), 300);
      expect(xpRequiredForLevel(10), 1000);
    });

    test('累计阈值：Lv1=0 / Lv2=100 / Lv3=300 / Lv4=600', () {
      expect(xpThresholdForLevel(1), 0);
      expect(xpThresholdForLevel(2), 100);
      expect(xpThresholdForLevel(3), 300);
      expect(xpThresholdForLevel(4), 600);
    });

    test('老用户 0 XP 从 Lv1 起算', () {
      expect(levelForXp(0), 1);
      expect(levelForXp(-10), 1);
    });

    test('达到阈值即升级，未达保持原级', () {
      expect(levelForXp(99), 1);
      expect(levelForXp(100), 2);
      expect(levelForXp(299), 2);
      expect(levelForXp(300), 3);
    });

    test('不设等级上限：每级都按 100 × 等级继续增长', () {
      expect(levelForXp(xpThresholdForLevel(50)), 50);
      expect(levelForXp(xpThresholdForLevel(50) - 1), 49);
      expect(xpRequiredForLevel(50), 5000);
    });
  });

  group('XpSnapshot', () {
    test('0 XP：Lv1 / 本级 0 / 距下一级 100', () {
      const snapshot = XpSnapshot.zero;
      expect(snapshot.totalXp, 0);
      expect(snapshot.level, 1);
      expect(snapshot.xpIntoLevel, 0);
      expect(snapshot.xpToNextLevel, 100);
    });

    test('刚好升级：本级进度归零，距离换成新级所需', () {
      final snapshot = XpSnapshot.fromTotal(100);
      expect(snapshot.level, 2);
      expect(snapshot.xpIntoLevel, 0);
      expect(snapshot.xpToNextLevel, 200);
    });

    test('本级中途：进度与剩余相加等于本级所需', () {
      final snapshot = XpSnapshot.fromTotal(140);
      expect(snapshot.level, 2);
      expect(snapshot.xpIntoLevel, 40);
      expect(snapshot.xpToNextLevel, 160);
      expect(snapshot.xpIntoLevel + snapshot.xpToNextLevel, xpRequiredForLevel(2));
    });

    test('一次跨多级：直接落到最高等级', () {
      final snapshot = XpSnapshot.fromTotal(xpThresholdForLevel(5) + 10);
      expect(snapshot.level, 5);
      expect(snapshot.xpIntoLevel, 10);
      expect(snapshot.xpToNextLevel, xpRequiredForLevel(5) - 10);
    });
  });
}
