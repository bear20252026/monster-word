// MonsterSpeech 台词引擎：变量渲染、去重窗口、每日预算跨日重置。
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/monster_speech.dart';

void main() {
  // 进程级 static 复位（每日预算 + 去重窗口现为 static 共享）：防跨用例顺序依赖。
  setUp(MonsterSpeech.resetForTest);

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
      const allVars = {'days': 12, 'streak': 5, 'balance': 233, 'stage': '尖角'};
      final seen = <String>{};
      for (var i = 0; i < 4; i++) {
        final out = speech.pick(SpeechSlot.dailyGreeting, vars: allVars);
        expect(seen.contains(out), isFalse, reason: '第 ${i + 1} 次不应与最近 3 条重复');
        seen.add(out);
      }
    });

    test('无通道的变量（值为 null 或键缺失）：含该占位符的模板整条跳过', () {
      // 审计 P2-1：balance 读不到时，「钱包里躺着 0 枚尖叫币」这类假数字一条都不许出现。
      final speech = MonsterSpeech(random: Random(3));
      final balanceLines = MonsterSpeech.templatesOf(SpeechSlot.dailyGreeting)
          .where((t) => t.contains('{balance}'))
          .map((t) => t.replaceAll('{balance}', '0'))
          .toSet();
      for (var i = 0; i < 12; i++) {
        final out = speech.pick(SpeechSlot.dailyGreeting, vars: const {'days': null, 'streak': null});
        expect(out.contains('{'), isFalse, reason: '不应留下未渲染占位符');
        expect(out.contains('尖叫币'), isFalse, reason: '无余额通道时不得报余额');
        expect(balanceLines.contains(out), isFalse);
      }
    });

    test('每槽都保有不含占位符的文案（pick 过滤后候选必非空）', () {
      for (final slot in SpeechSlot.values) {
        expect(MonsterSpeech.templatesOf(slot).any((t) => !t.contains('{')), isTrue, reason: '$slot 需要至少一条不带变量的保底文案');
      }
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
