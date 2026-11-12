// 记忆兽生成器口径：词长体型/稀有度边界、词性耳朵映射、无词性兜底、文案红线。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/memory_beast.dart';
import 'package:word_app/models/word.dart';

Word _word(String text, {String pos = ''}) {
  final interpret = pos.isEmpty ? '' : '[{"t":"$pos","def":[{"cn":"测试释义","en":"test"}]}]';
  return Word(word: text, interpret: interpret);
}

void main() {
  bool hasEmoji(String s) {
    for (final r in s.runes) {
      if ((r >= 0x1F000 && r <= 0x1FAFF) || (r >= 0x2600 && r <= 0x27BF) || (r >= 0xFE00 && r <= 0xFE0F)) {
        return true;
      }
    }
    return false;
  }

  group('词长 → 体型（含边界）', () {
    test('≤4 小巧 / 5-7 标准 / ≥8 修长', () {
      expect(beastBuildFor(1), BeastBuild.petite);
      expect(beastBuildFor(4), BeastBuild.petite);
      expect(beastBuildFor(5), BeastBuild.standard);
      expect(beastBuildFor(7), BeastBuild.standard);
      expect(beastBuildFor(8), BeastBuild.lanky);
      expect(beastBuildFor(20), BeastBuild.lanky);
    });

    test('体型比例：小巧更圆、修长更高', () {
      final petite = memoryBeastFor(_word('cat'));
      final lanky = memoryBeastFor(_word('understand'));
      expect(petite.bodyWidthFactor, greaterThan(petite.bodyHeightFactor));
      expect(lanky.bodyHeightFactor, greaterThan(lanky.bodyWidthFactor));
    });
  });

  group('词长 → 稀有度（demo 难度代理，含边界）', () {
    test('≤5 常见 / 6-8 少见 / ≥9 稀有', () {
      expect(beastRarityFor(5), BeastRarity.common);
      expect(beastRarityFor(6), BeastRarity.uncommon);
      expect(beastRarityFor(8), BeastRarity.uncommon);
      expect(beastRarityFor(9), BeastRarity.rare);
    });
  });

  group('词性 → 耳朵', () {
    test('名词圆耳 / 动词尖耳 / 形容词垂耳 / 副词角耳', () {
      expect(beastEarsFor('n.'), BeastEars.round);
      expect(beastEarsFor('vt.'), BeastEars.pointy);
      expect(beastEarsFor('vi.'), BeastEars.pointy);
      expect(beastEarsFor('adj.'), BeastEars.floppy);
      expect(beastEarsFor('adv.'), BeastEars.tufted);
    });

    test('大小写与空白容错', () {
      expect(beastEarsFor(' N. '), BeastEars.round);
      expect(beastEarsFor('ADJ.'), BeastEars.floppy);
    });

    test('空/未知词性回退圆耳（没有词性的词也有兽）', () {
      expect(beastEarsFor(null), BeastEars.round);
      expect(beastEarsFor(''), BeastEars.round);
      expect(beastEarsFor('xyz.'), BeastEars.round);
    });
  });

  group('memoryBeastFor 整词生成', () {
    test('词 + 首条词性 → 完整规格', () {
      final spec = memoryBeastFor(_word('run', pos: 'vi.'));
      expect(spec.word, 'run');
      expect(spec.build, BeastBuild.petite);
      expect(spec.ears, BeastEars.pointy);
      expect(spec.rarity, BeastRarity.common);
    });

    test('无结构化释义不缺席（圆耳兜底）', () {
      final spec = memoryBeastFor(Word(word: 'hello', interpret: '你好'));
      expect(spec.ears, BeastEars.round);
      expect(spec.word, 'hello');
    });

    test('首尾空白修剪后计长', () {
      final spec = memoryBeastFor(_word('  cat  '));
      expect(spec.word, 'cat');
      expect(spec.build, BeastBuild.petite);
    });

    test('多词性取首条', () {
      final w = Word(word: 'light', interpret: '[{"t":"n.","def":[{"cn":"光"}]},{"t":"adj.","def":[{"cn":"轻"}]}]');
      expect(memoryBeastFor(w).ears, BeastEars.round);
    });
  });

  group('文案红线（只陈述，不评价不焦虑）', () {
    test('全部展示名零 emoji', () {
      final all = [...beastRarityLabels.values, ...beastBuildLabels.values, ...beastEarsLabels.values];
      for (final text in all) {
        expect(hasEmoji(text), isFalse, reason: '不得用 emoji：$text');
      }
    });

    test('稀有度名不含比较/评价措辞', () {
      for (final text in beastRarityLabels.values) {
        for (final banned in ['高级', '低级', '厉害', '差', '强弱']) {
          expect(text, isNot(contains(banned)), reason: '稀有度只陈述档位：$text');
        }
      }
    });

    test('三档展示名齐全且互不相同', () {
      expect(beastRarityLabels.length, BeastRarity.values.length);
      expect(beastRarityLabels.values.toSet().length, BeastRarity.values.length);
    });
  });
}
