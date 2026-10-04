// MonsterVoice 四道闸真值表：设置开关 / 音效档位 / 引擎忙 / 中文语音可用性。
//
// 全部注入假实现，不碰真实 flutter_tts 插件（单测环境无平台通道）。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/monster_rhythm.dart';
import 'package:word_app/core/utils/monster_voice.dart';
import 'package:word_app/core/utils/sfx.dart';
import 'package:word_app/core/utils/sfx_settings.dart';

void main() {
  final spoken = <String>[];

  Completer<void>? hold;

  MonsterVoice build({bool engineBusy = false, bool? availability = true, Object? throwOnSpeak}) {
    return MonsterVoice(
      speak: (text) async {
        if (throwOnSpeak != null) throw throwOnSpeak;
        if (hold != null) await hold!.future;
        spoken.add(text);
      },
      availability: () async => availability,
      engineBusy: () => engineBusy,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    spoken.clear();
    hold = null;
    SfxSettings.current = SfxMode.all;
    MonsterVoiceSettings.enabled = true;
    // 夜息闸（W4.5）时间免疫：默认 pin 白天，夜间行为由专门用例 pin 23 点。
    MonsterRhythm.nowOverride = () => DateTime(2026, 10, 4, 10);
  });
  tearDown(MonsterRhythm.resetForTest);

  group('出声条件', () {
    test('四道闸全过：原样念出并返回 true', () async {
      final said = await build().say('我就知道你会回来！');
      expect(said, isTrue);
      expect(spoken, ['我就知道你会回来！']);
    });

    test('「怪兽语音」关掉：不出声', () async {
      MonsterVoiceSettings.enabled = false;
      expect(await build().say('你好'), isFalse);
      expect(spoken, isEmpty);
    });

    test('音效处于仅视觉/全静音：一律不出声（与三态静音键联动）', () async {
      SfxSettings.current = SfxMode.visualOnly;
      expect(await build().say('你好'), isFalse);
      SfxSettings.current = SfxMode.silent;
      expect(await build().say('你好'), isFalse);
      expect(spoken, isEmpty);
    });

    test('引擎正在朗读单词/例句：怪兽让路，不抢同一套系统 TTS', () async {
      expect(await build(engineBusy: true).say('你好'), isFalse);
      expect(spoken, isEmpty);
    });

    test('确认缺中文语音包：不出声（降级回文案气泡）', () async {
      expect(await build(availability: false).say('你好'), isFalse);
      expect(spoken, isEmpty);
    });

    test('平台不返回语言列表（无从判断）：按可用先试一次', () async {
      expect(await build(availability: null).say('你好'), isTrue);
      expect(spoken, ['你好']);
    });

    test('夜息闸（W4.5）：22:00–6:00 它睡了——任何时刻都不出声，气泡照常', () async {
      MonsterRhythm.nowOverride = () => DateTime(2026, 10, 4, 23);
      expect(await build().say('我就知道你会回来！'), isFalse);
      expect(spoken, isEmpty);
      // 凌晨同样安静
      MonsterRhythm.nowOverride = () => DateTime(2026, 10, 5, 3);
      expect(await build().say('你好'), isFalse);
      expect(spoken, isEmpty);
    });
    test('发声实际抛错：返回 false 不炸调用方（仪式不被声音拖垮）', () async {
      expect(await build(throwOnSpeak: StateError('no voice')).say('你好'), isFalse);
      expect(spoken, isEmpty);
    });

    test('空文本/纯空白：不出声', () async {
      expect(await build().say(''), isFalse);
      expect(await build().say('   '), isFalse);
      expect(spoken, isEmpty);
    });

    test('一场仪式只说一句：发声期间的第二个请求直接丢弃（不排队堆叠）', () async {
      hold = Completer<void>();
      final first = build().say('第一句');
      final second = await build().say('第二句'); // 第一句还没说完
      expect(second, isFalse, reason: '重入必须被拦下，否则台词会叠着念');
      hold!.complete();
      expect(await first, isTrue);
      expect(spoken, ['第一句']);
      // 闸门已复位：下一场仪式还能说话。
      expect(await build().say('下一场'), isTrue);
    });
  });

  group('开关持久化', () {
    test('默认开；setEnabled 落 SP 后 load 读回', () async {
      expect(MonsterVoiceSettings.enabled, isTrue);
      await MonsterVoiceSettings.setEnabled(false);
      expect(MonsterVoiceSettings.enabled, isFalse);
      await MonsterVoiceSettings.load();
      expect(MonsterVoiceSettings.enabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(MonsterVoiceSettings.key), isFalse);
    });

    test('SP 无记录时 load 回到默认开', () async {
      await MonsterVoiceSettings.setEnabled(true);
      await MonsterVoiceSettings.load();
      expect(MonsterVoiceSettings.enabled, isTrue);
    });
  });
}
