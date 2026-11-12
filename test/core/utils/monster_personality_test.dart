// 怪兽性格原语：解析回退、三组待机参数、三套台词组的不变式与文案红线。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/monster_personality.dart';
import 'package:word_app/core/utils/monster_speech.dart';

void main() {
  bool hasEmoji(String s) {
    for (final r in s.runes) {
      if ((r >= 0x1F000 && r <= 0x1FAFF) || (r >= 0x2600 && r <= 0x27BF) || (r >= 0xFE00 && r <= 0xFE0F)) {
        return true;
      }
    }
    return false;
  }

  group('parsePersonality', () {
    test('合法枚举名原样解析', () {
      for (final p in MonsterPersonality.values) {
        expect(parsePersonality(p.name), p);
      }
    });

    test('null/空串/未知值回退活泼（老档无性格字段不重演仪式）', () {
      expect(parsePersonality(null), MonsterPersonality.lively);
      expect(parsePersonality(''), MonsterPersonality.lively);
      expect(parsePersonality('angry'), MonsterPersonality.lively);
    });
  });

  group('三组待机动画', () {
    test('每种性格都有参数且互不相同', () {
      final periods = <int>{};
      for (final p in MonsterPersonality.values) {
        final m = idleMotions[p]!;
        expect(m.amplitude, greaterThan(0));
        expect(m.periodMs, greaterThan(0));
        periods.add(m.periodMs);
      }
      expect(periods.length, MonsterPersonality.values.length, reason: '三组待机周期必须可区分');
    });

    test('活泼最快、安静最慢（设计口径）', () {
      expect(
        idleMotions[MonsterPersonality.lively]!.periodMs,
        lessThan(idleMotions[MonsterPersonality.calm]!.periodMs),
      );
    });
  });

  group('三套台词组不变式', () {
    test('每槽至少一条不含占位符（pick 过滤后候选必非空）', () {
      for (final p in MonsterPersonality.values) {
        for (final entry in personalityTemplates[p]!.entries) {
          expect(entry.value.any((t) => !t.contains('{')), isTrue, reason: '$p/${entry.key} 需要至少一条不带变量的保底文案');
        }
      }
    });

    test('模板只使用引擎认识的占位符', () {
      const known = ['days', 'streak', 'balance', 'stage', 'name', 'due'];
      final placeholder = RegExp(r'\{(\w+)\}');
      for (final p in MonsterPersonality.values) {
        for (final entry in personalityTemplates[p]!.entries) {
          for (final t in entry.value) {
            for (final m in placeholder.allMatches(t)) {
              expect(known, contains(m.group(1)), reason: '$p/${entry.key} 出现未知占位符：$t');
            }
          }
        }
      }
    });

    test('零 emoji 与无焦虑措辞（与主台词同红线）', () {
      const banned = ['你怎么', '退步', '又拖', '再不', '居然', '太差', '亏', '过期', '浪费', '赶紧'];
      for (final p in MonsterPersonality.values) {
        for (final entry in personalityTemplates[p]!.entries) {
          for (final t in entry.value) {
            expect(hasEmoji(t), isFalse, reason: '不得用 emoji：$t');
            for (final b in banned) {
              expect(t, isNot(contains(b)), reason: '不得制造焦虑：$t');
            }
          }
        }
      }
    });

    test('展示名与简介齐全', () {
      for (final p in MonsterPersonality.values) {
        expect(personalityLabels[p], isNotNull);
        expect(personalityDescriptions[p], isNotNull);
      }
    });
  });

  group('MonsterSpeech 性格集成', () {
    setUp(MonsterSpeech.resetForTest);
    tearDown(MonsterSpeech.resetForTest);

    test('指定性格只从该性格组选条', () {
      for (final p in MonsterPersonality.values) {
        final speech = MonsterSpeech(personality: p);
        final rendered = personalityTemplates[p]![SpeechSlot.dailyGreeting]!
            .map((t) => t.replaceAll('{days}', '12'))
            .toSet();
        for (var i = 0; i < 6; i++) {
          final out = speech.pick(SpeechSlot.dailyGreeting, vars: const {'days': 12});
          expect(rendered, contains(out), reason: '$p 的台词必须来自本性格组');
        }
      }
    });

    test('性格组未覆盖的槽位回退主表', () {
      final speech = MonsterSpeech(personality: MonsterPersonality.calm);
      final out = speech.pick(SpeechSlot.suggestThreeWordGroup, vars: const {});
      final base = MonsterSpeech.templatesOf(SpeechSlot.suggestThreeWordGroup, personality: MonsterPersonality.calm);
      expect(base, contains(out));
    });

    test('缺变量时含占位符的性格模板整条跳过', () {
      final speech = MonsterSpeech(personality: MonsterPersonality.stubborn);
      for (var i = 0; i < 8; i++) {
        final out = speech.pick(SpeechSlot.dailyGreeting, vars: const {});
        expect(out.contains('{'), isFalse);
      }
    });

    test('templatesOf 按性格返回对应组', () {
      expect(
        MonsterSpeech.templatesOf(SpeechSlot.petHappy, personality: MonsterPersonality.calm),
        personalityTemplates[MonsterPersonality.calm]![SpeechSlot.petHappy],
      );
    });
  });
}
