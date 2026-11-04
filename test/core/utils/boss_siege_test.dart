// Boss 战围城口径：档位边界、敌列上限、守城文案的事实性。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/boss_siege.dart';

void main() {
  // emoji_hygiene_test 对 lib 非注释行零 emoji（Dart RegExp 不接受 \u{...} 形式，按 rune 判）。
  bool hasEmoji(String s) {
    for (final r in s.runes) {
      if ((r >= 0x1F000 && r <= 0x1FAFF) || (r >= 0x2600 && r <= 0x27BF) || (r >= 0xFE00 && r <= 0xFE0F)) {
        return true;
      }
    }
    return false;
  }

  group('siegeTierFor 档位边界', () {
    test('0 及负数 = cleared（没仗可打不算守住）', () {
      expect(siegeTierFor(0), SiegeTier.cleared);
      expect(siegeTierFor(-3), SiegeTier.cleared);
    });

    test('1-9 raid / 10-39 siege / 40+ legion', () {
      expect(siegeTierFor(1), SiegeTier.raid);
      expect(siegeTierFor(siegeDueThreshold - 1), SiegeTier.raid);
      expect(siegeTierFor(siegeDueThreshold), SiegeTier.siege);
      expect(siegeTierFor(legionDueThreshold - 1), SiegeTier.siege);
      expect(siegeTierFor(legionDueThreshold), SiegeTier.legion);
      expect(siegeTierFor(500), SiegeTier.legion);
    });
  });

  group('siegeNarrative 只陈述事实', () {
    test('非空档都带真实剩余数，且不留占位', () {
      for (final tier in SiegeTier.values) {
        final text = siegeNarrative(tier, 7);
        expect(text, isNotEmpty);
        if (tier != SiegeTier.cleared) {
          expect(text, contains('7'), reason: '$tier 档应把剩余数说出口');
        }
      }
    });

    test('文案零 emoji（emoji_hygiene_test 对 lib 非注释行零容忍，这里先自锁）', () {
      for (final tier in SiegeTier.values) {
        expect(hasEmoji(siegeNarrative(tier, 3)), isFalse, reason: '不得用 emoji 表达情绪');
      }
      expect(hasEmoji(siegeVictoryLine), isFalse);
      expect(hasEmoji(siegeQuietLine), isFalse);
    });

    test('不出现羞辱/催促式措辞（世界观红线：只担心，不指责）', () {
      final all = [for (final tier in SiegeTier.values) siegeNarrative(tier, 99), siegeVictoryLine, siegeQuietLine];
      for (final text in all) {
        for (final banned in ['你怎么', '退步', '又拖', '再不', '居然', '太差']) {
          expect(text, isNot(contains(banned)), reason: '不得指责用户：$text');
        }
      }
    });
  });

  group('marauderBadgeCounts 敌列上限', () {
    test('<=12 全画、无溢出', () {
      expect(marauderBadgeCounts(0), (visible: 0, overflow: 0));
      expect(marauderBadgeCounts(5), (visible: 5, overflow: 0));
      expect(marauderBadgeCounts(maxVisibleMarauders), (visible: maxVisibleMarauders, overflow: 0));
    });

    test('>12 画满 12 只，其余并进 +N', () {
      expect(marauderBadgeCounts(37), (visible: maxVisibleMarauders, overflow: 37 - maxVisibleMarauders));
      expect(marauderBadgeCounts(-1), (visible: 0, overflow: 0));
    });
  });

  test('阈值单源：大军压境阈值 = 心情机 worried 阈值（40）', () {
    // 两处各写一个 40 迟早漂移；这里锁住数值本身。
    expect(legionDueThreshold, 40);
    expect(siegeDueThreshold, 10);
  });

  group('Boss v2 触发口径', () {
    BossBattlePhase phase({
      bool hadDueAtStart = true,
      int total = 40,
      int done = 0,
      bool hasWord = true,
      bool introPlayedToday = true,
    }) => resolveBossPhase(
      hadDueAtStart: hadDueAtStart,
      total: total,
      done: done,
      hasWord: hasWord,
      introPlayedToday: introPlayedToday,
    );

    test('39/40/41 边界：只有 ≥40 才出现', () {
      expect(phase(total: 39), BossBattlePhase.absent);
      expect(phase(total: 40), BossBattlePhase.active);
      expect(phase(total: 41), BossBattlePhase.active);
    });

    test('阈值与 legionDueThreshold 同源（不新增第二个 40）', () {
      expect(bossTriggerDueThreshold, legionDueThreshold);
      expect(bossTriggerDueThreshold, 40);
    });

    test('到期为空：整本队列兜底装了几百词也不误触发', () {
      expect(phase(hadDueAtStart: false, total: 500), BossBattlePhase.absent);
      expect(phase(hadDueAtStart: false, total: 40), BossBattlePhase.absent);
    });

    test('开局后剩余跌破阈值仍是 active（闩锁，中途不再看阈值）', () {
      // 120 词答掉 100（剩 20 < 40）、40 词答掉 39（剩 1）：都不许把头目判没。
      expect(phase(total: 120, done: 100), BossBattlePhase.active);
      expect(phase(total: 40, done: 39), BossBattlePhase.active);
    });

    test('currentWord == null 是唯一退场路径：转 victory', () {
      expect(phase(total: 40, done: 40, hasWord: false), BossBattlePhase.victory);
      expect(phase(total: 120, done: 120, hasWord: false), BossBattlePhase.victory);
    });

    test('不足阈值时即便没有当前词也不是 victory（没开战就不庆祝）', () {
      expect(phase(total: 39, done: 39, hasWord: false), BossBattlePhase.absent);
    });

    test('当日首次入场：done==0 且没播过 → pendingIntro；播过 → active', () {
      expect(phase(total: 40, introPlayedToday: false), BossBattlePhase.pendingIntro);
      expect(phase(total: 40, introPlayedToday: true), BossBattlePhase.active);
      expect(phase(total: 40, done: 1, introPlayedToday: false), BossBattlePhase.active);
    });
  });

  group('Boss v2 单局上限与步数', () {
    test('sessionDueCount 在 120 处截断，负数按 0', () {
      expect(sessionDueCount(dueAtStart: -5), 0);
      expect(sessionDueCount(dueAtStart: 0), 0);
      expect(sessionDueCount(dueAtStart: 39), 39);
      expect(sessionDueCount(dueAtStart: 119), 119);
      expect(sessionDueCount(dueAtStart: 120), reviewSessionCap);
      expect(sessionDueCount(dueAtStart: 121), reviewSessionCap);
      expect(sessionDueCount(dueAtStart: 500), reviewSessionCap);
    });

    test('bossRemainingSteps 有界在 0..total', () {
      expect(bossRemainingSteps(0, 40), 40);
      expect(bossRemainingSteps(39, 40), 1);
      expect(bossRemainingSteps(40, 40), 0);
      expect(bossRemainingSteps(41, 40), 0);
      expect(bossRemainingSteps(0, 0), 0);
    });

    test('bossStepLabel：第 x / N 步 + 剩余步数；没有一局时留空', () {
      expect(bossStepLabel(0, 0), '');
      expect(bossStepLabel(0, 40), '第 1 / 40 步 · 还剩 40 步');
      expect(bossStepLabel(39, 40), '第 40 / 40 步 · 还剩 1 步');
      expect(bossStepLabel(40, 40), '第 40 / 40 步 · 还剩 0 步');
      expect(bossStepLabel(0, reviewSessionCap), '第 1 / 120 步 · 还剩 120 步');
    });

    test('bossDayStamp 是零填充的 yyyy-MM-dd', () {
      expect(bossDayStamp(DateTime(2026, 11, 5)), '2026-11-05');
      expect(bossDayStamp(DateTime(2026, 1, 9)), '2026-01-09');
    });
  });

  group('Boss v2 文案底线', () {
    test('零 emoji；不写「进度已保存 / 随时接着走」这类承诺', () {
      final lines = [bossVictoryLine, bossNarrative(remaining: 5), bossNarrative(remaining: 0)];
      for (final text in lines) {
        expect(hasEmoji(text), isFalse, reason: '不得用 emoji：$text');
        for (final banned in ['进度已保存', '随时接着走', '已保存']) {
          expect(text, isNot(contains(banned)), reason: '不得做持久化承诺：$text');
        }
        for (final banned in ['消灭', '击杀', '杀死']) {
          expect(text, isNot(contains(banned)), reason: '世界观红线：只击退不消灭：$text');
        }
      }
    });
  });
}
