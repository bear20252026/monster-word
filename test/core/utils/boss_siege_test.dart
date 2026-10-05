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
}
