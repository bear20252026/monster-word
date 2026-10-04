// 怪兽发声闸门（「怪兽开口」）：只在三个时刻说话——破壳自报家门、回归 welcomeBack、进化那一句。
//
// 出声要同时过五道闸（真值表由 test/core/utils/monster_voice_test 锁定）：
//   ① 设置里「怪兽语音」开着（默认开）；
//   ② 总音效处于「全开」档——visualOnly / silent 一律不出声（与 v2.11.8 的三态静音键联动）；
//   ③ 夜息（W4.5）：22:00–6:00 它睡了，任何时刻都不出声（台词气泡照常，
//      破壳/回归/进化夜里被叫醒也只动嘴不出声——深夜外放不可接受）；
//   ④ 系统引擎此刻没在朗读单词或例句（同一 TTS 引擎一次只能说一句，怪兽必须让路）；
//   ⑤ 设备装了中文语音（探不到就按可用试一次，失败即静默降级回文案气泡，不再反复敲引擎）。
//
// 复用 flutter_tts 系统合成：零新依赖、零网络，守住「离线完成学习闭环」的产品承诺。
// 世界观红线：台词仍由 MonsterSpeech 出真值，发声只是把同一句话念出来，不新增评价性文案。
import 'package:word_app/core/utils/swallowed_error_report.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/audio/system_tts.dart';
import 'package:word_app/core/utils/sfx.dart';
import 'package:word_app/core/utils/monster_rhythm.dart';
import 'package:word_app/core/utils/sfx_settings.dart';

/// 「怪兽语音」开关持久化（SP 单键，默认开）。
class MonsterVoiceSettings {
  MonsterVoiceSettings._();

  static const String key = 'monster_voice_enabled';

  static bool enabled = true;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(key) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}

/// 怪兽发声闸门。生产用 [MonsterVoice.system]；测试注入依赖验证真值表。
class MonsterVoice {
  MonsterVoice({this.speak, this.availability, this.engineBusy});

  /// 全 app 共用的唯一发声道（系统引擎也只有一个，多处并发没有意义）。
  static final MonsterVoice system = MonsterVoice();

  /// 测试注入缝：不传即走系统 TTS 单例。
  final Future<void> Function(String text)? speak;
  final Future<bool?> Function()? availability;
  final bool Function()? engineBusy;

  /// 一场仪式只说一句：正在发声时后来的请求直接丢弃（不排队，排队会让台词堆叠）。
  static bool _talking = false;

  /// 念出 [text]；返回是否真的出声（false=被闸门拦下，调用方无需处理，文案气泡照常显示）。
  Future<bool> say(String text) async {
    final line = text.trim();
    if (line.isEmpty) return false;
    if (!MonsterVoiceSettings.enabled) return false;
    if (SfxSettings.current != SfxMode.all) return false;
    // 夜息闸（W4.5）：睡着的怪兽不出声，深夜 TTS 外放不可接受。
    if (MonsterRhythm.isSleepTime()) return false;
    if (_talking) return false;
    // 让路给单词/例句朗读（同一系统引擎，一次只能说一句）。
    if (engineBusy?.call() ?? SystemTts().isSpeaking) return false;
    // 占用发声道必须在任何 await 之前完成——否则两场仪式会在同一帧里双双通过闸门。
    _talking = true;
    try {
      if (await (availability?.call() ?? SystemTts().chineseVoiceAvailable()) == false) return false;
      await (speak?.call(line) ?? SystemTts().speakChinese(line));
      if (speak == null) {
        // Android 侧 speak() 入队即返回：占用保持到引擎真正念完（isSpeaking
        // 回落），否则紧随其后的第二场仪式会在引擎尚未开口的窗口截断上一句
        // （REG-VOICE-001 只修了占用侧，这里是释放侧）。
        for (var i = 0; i < 100; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (!SystemTts().isSpeaking) break;
        }
      }
      return true;
    } catch (e, s) {
      // 缺中文语音包 / 引擎异常：退回文案气泡，并记住本进程不再敲引擎（C 级合理降级）。
      if (availability == null) SystemTts().markChineseVoiceUnavailable();
      reportSwallowedError('怪兽发声失败（降级为文案气泡）', e, s);
      return false;
    } finally {
      _talking = false;
    }
  }
}
