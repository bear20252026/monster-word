// 单元测试：音频播放器 _needPlay 约定（源码级守卫，防回退）
//
// 单词发音默认自动播（REG-AUDIO-001：回退为 false 会让所有单词发音静默失效），
// 例句播放器默认不自动播（由用户点击触发，防状态机异常）。
// 旧版本文件断言的是测试内自建常量（恒真），已改为对生产源码的真实守卫。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioPlayer _needPlay 约定', () {
    test('单词播放器默认 true / 例句播放器默认 false', () {
      final phonetic = File('lib/core/audio/audio_player_phonetic.dart').readAsStringSync();
      final sentence = File('lib/core/audio/audio_player_sentence.dart').readAsStringSync();
      expect(
        phonetic.contains('final bool _needPlay = true;'),
        isTrue,
        reason: '单词发音默认回退 false 会让所有单词发音静默失效（REG-AUDIO-001）',
      );
      expect(sentence.contains('final bool _needPlay = false;'), isTrue, reason: '例句加载后自动播放会打断用户节奏，必须由用户点击触发');
    });

    test('单词 TTS 兜底直连第三方 https 接口（URL 不做本地改写）', () {
      final src = File('lib/core/audio/audio_player_text.dart').readAsStringSync();
      expect(src.contains('https://dict.youdao.com/dictvoice'), isTrue, reason: 'TTS 兜底 URL 应直连第三方 https 接口');
    });
  });
}
