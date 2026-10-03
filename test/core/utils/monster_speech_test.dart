// MonsterSpeech 台词引擎：变量渲染、去重窗口、每日预算跨日重置。
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/monster_speech.dart';

void main() {
  group('pick（变量渲染与去重）', () {
    test('变量替换：days/streak/balance/stage 全渲染', () {
      final speech = MonsterSpeech(random: Random(1));
      final out = speech.pick(SpeechSlot.milestone, vars: {'days': 30, 'streak': 7, 'balance': 520, 'stage': '飞翼'});
      expect(out.contains('{days}'), isFalse);
      expect(out.contains('{streak}'), isFalse);
      expect(out.contains('{balance}'), isFalse);
      expect(out.contains('{stage}'), isFalse);
    });

    test('同槽连续 4 次不重复（去重窗口 3）', () {
      final speech = MonsterSpeech(random: Random(7));
      final seen = <String>{};
      for (var i = 0; i < 4; i++) {
        final out = speech.pick(SpeechSlot.dailyGreeting, vars: const {});
        expect(seen.contains(out), isFalse, reason: '第 ${i + 1} 次不应与最近 3 条重复');
        seen.add(out);
      }
    });

    test('缺失变量按空串渲染，不抛错', () {
      final speech = MonsterSpeech(random: Random(3));
      final out = speech.pick(SpeechSlot.welcomeBack, vars: const {});
      expect(out, isNotEmpty);
      expect(out.contains('{'), isFalse);
    });
  });

  group('每日预算（≤3，跨日重置）', () {
    test('同日第 4 次 canSpeak=false', () {
      var now = DateTime(2026, 10, 3, 8);
      final speech = MonsterSpeech(now: () => now, random: Random(1));
      expect(speech.canSpeak(), isTrue);
      speech.consumeBudget();
      speech.consumeBudget();
      speech.consumeBudget();
      expect(speech.canSpeak(), isFalse);
    });

    test('跨日自动重置', () {
      var now = DateTime(2026, 10, 3, 23);
      final speech = MonsterSpeech(now: () => now, random: Random(1));
      speech.consumeBudget();
      speech.consumeBudget();
      speech.consumeBudget();
      expect(speech.canSpeak(), isFalse);
      now = DateTime(2026, 10, 4, 0, 1);
      expect(speech.canSpeak(), isTrue, reason: '跨日重置');
    });

    test('dayKeyOf 口径：yyyy-MM-dd 补零', () {
      expect(MonsterSpeech.dayKeyOf(DateTime(2026, 1, 5)), '2026-01-05');
      expect(MonsterSpeech.dayKeyOf(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });
}
