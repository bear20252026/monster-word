// SfxPlayer 音量表（REG-SFX-001 配套；测试审计 #2「音效行为零覆盖」补齐）。
//
// volumeFor 纯函数锚点：三态 × 四通道 × 昼夜。静音档「真的不播」由
// SfxPlayer.play 的 mode 短路保证，此处锁音量语义自洽（非 all 恒 0）。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/sfx.dart';

void main() {
  group('volumeFor 纯函数表', () {
    test('全开档：通道基准音量（celebrate 1.0 / quiz 0.85 / ui 0.6 / monster 0.8）', () {
      expect(SfxPlayer.volumeFor(SfxChannel.celebrate, mode: SfxMode.all, isNight: false), 1.0);
      expect(SfxPlayer.volumeFor(SfxChannel.quiz, mode: SfxMode.all, isNight: false), 0.85);
      expect(SfxPlayer.volumeFor(SfxChannel.ui, mode: SfxMode.all, isNight: false), closeTo(0.6, 1e-9));
      expect(SfxPlayer.volumeFor(SfxChannel.monster, mode: SfxMode.all, isNight: false), 0.8);
    });

    test('夜间：统一 ×0.5（约 -6dB）', () {
      expect(SfxPlayer.volumeFor(SfxChannel.celebrate, mode: SfxMode.all, isNight: true), 0.5);
      expect(SfxPlayer.volumeFor(SfxChannel.ui, mode: SfxMode.all, isNight: true), closeTo(0.3, 1e-9));
      expect(SfxPlayer.volumeFor(SfxChannel.monster, mode: SfxMode.all, isNight: true), 0.4);
    });

    test('仅视觉 / 全静音：恒 0（静音语义自洽）', () {
      for (final mode in [SfxMode.visualOnly, SfxMode.silent]) {
        for (final channel in SfxChannel.values) {
          expect(SfxPlayer.volumeFor(channel, mode: mode, isNight: false), 0, reason: '$mode/$channel');
        }
      }
    });
  });
}
