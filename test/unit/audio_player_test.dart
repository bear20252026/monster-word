// 单元测试：音频播放器 _needPlay 约定（源码级守卫，防回退）
//
// 单词发音默认自动播（REG-AUDIO-001：回退为 false 会让所有单词发音静默失效）。
// 例句播放器原有一个恒为 false 的 _needPlay 字段（2026-10-07 审计确认为
// 死代码并删除：其 if 分支恒走、else 不可达）；守卫相应改为锁定「例句
// 播放器不再引入 _needPlay 门控」——加载后自动播放的行为约束由此保持。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioPlayer _needPlay 约定', () {
    test('单词播放器默认 true / 例句播放器无自动播门控', () {
      final phonetic = File('lib/core/audio/audio_player_phonetic.dart').readAsStringSync();
      final sentence = File('lib/core/audio/audio_player_sentence.dart').readAsStringSync();
      expect(
        phonetic.contains('final bool _needPlay = true;'),
        isTrue,
        reason: '单词发音默认回退 false 会让所有单词发音静默失效（REG-AUDIO-001）',
      );
      expect(
        sentence.contains('_needPlay'),
        isFalse,
        reason: '例句播放器的 _needPlay 是恒 false 死字段（2026-10 已删）；如需恢复自动播门控必须先回归 REG-FDB-001 同款行为测试',
      );
    });

    test('单词 TTS 兜底直连第三方 https 接口（URL 不做本地改写）', () {
      final src = File('lib/core/audio/audio_player_text.dart').readAsStringSync();
      expect(src.contains('https://dict.youdao.com/dictvoice'), isTrue, reason: 'TTS 兜底 URL 应直连第三方 https 接口');
    });
  });
}
