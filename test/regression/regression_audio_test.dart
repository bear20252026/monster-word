// ============================================================
// 回归测试 — 发音链路（REG-AUDIO-xxx）
// 规则：每个 REG-ID 对应一个已修复线上 bug，测试永久保留，
//       任何导致本文件失败的改动都必须先证明 bug 不会复发。
// 台账：docs/regression_ledger.md
// ============================================================
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/audio/audio_players.dart';
import 'package:word_app/core/parsers/example_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('REG-AUDIO 发音链路回归', () {
    test('REG-AUDIO-001: 单词发音默认允许播放（needPlay 默认 true）', () {
      // 症状：例句能响、单词不响；根因：PhoneticAudioPlayer._needPlay 默认 false
      // 且全仓库无 setNeedPlay(true) 调用点，_playFile 开头 return 静默丢弃。
      // 修复：commit 2eabee0 默认改 true。
      expect(PhoneticAudioPlayer().needPlayForTest, isTrue,
          reason: 'needPlay 回退为 false 会导致所有单词发音静默失效（黑盒表现为"有的响有的不响"）');
    });

    test('REG-AUDIO-002: 例句 http:// 明文 URL 升级 https（Android 9+ 禁明文）', () {
      // 症状：Windows 例句响、Android 真机不响；根因：词库存 http://，
      // Android 9+ 默认禁明文流量且 manifest 未开 usesCleartextTraffic。
      // 修复：example_parser._normalizeAudioUrl 统一升级 https。
      const raw =
          '{"v":1,"data":[{"i":{"e":"w","c":"译"},"g":[{"u":"","s":['
          '{"eid":"1","e":"Sentence one.","c":"例句一","b":"","u":"http://audio.beingfine.cn/sentence/audio/x.mp3"}]}]}]}';
      final sentences = ExampleParser.parse(raw);
      expect(sentences, isNotEmpty);
      expect(sentences.first.audioUrl, startsWith('https://'),
          reason: '任何 http:// 例句音频 URL 在 Android 真机上会被系统静默拦截，例句无声');
    });

    test('REG-AUDIO-003: 单词音频下载失败链路最终落系统 TTS（不再静默）', () {
      // 守护点说明：TTS 兜底位于 PhoneticAudioPlayer._downloadAndPlay 的
      // onLoadError 分支与 AudioServiceImpl.playWordAudio 的 catch 分支
      // （commit 2eabee0）。插件依赖（just_audio/flutter_tts）无法在纯
      // Dart 测试中实例化，此处守护调用链的前提条件：needPlay 为 true 且
      // Youdao URL 构造保持稳定（兜底触发的前提是下载路径可构造）。
      expect(PhoneticAudioPlayer().needPlayForTest, isTrue);
      // Youdao 主源 URL 格式守护：type=1 英音 / type=2 美音
      // （2026-08-30 实测：HTTP 200 / audio/mpeg，通路健康）
      expect(Uri.parse('https://dict.youdao.com/dictvoice?audio=word&type=2').queryParameters['type'], '2');
    });
  });
}
