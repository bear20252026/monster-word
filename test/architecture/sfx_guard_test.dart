// SfxGuard：音效唯一出口与资产清单守卫（同 haptics_gate/debug_print_guard 范式）。
//
// ① lib/ 下 audioplayers 直接使用仅允许 sfx.dart 出口；
// ② assets/sfx/ 下的 .wav 必须与 Sfx 枚举一一对应（防资产/代码漂移）；
// ③ 音效总预算 ≤1MB（蓝图口径）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/sfx.dart';

void main() {
  test('音效唯一出口：lib/ 下 audioplayers 直接使用仅存在于 sfx.dart', () {
    final violations = <String>[];
    final roots = [
      'lib/features',
      'lib/app',
      'lib/core',
      'lib/widgets',
      'lib/models',
      'lib/theme',
      'lib/tokens',
      'lib/utils',
      'lib/main.dart', // 2026-10 审计 Q1：兜底页/入口直用也须被守卫看见
    ];
    // 发音系统（TTS/例句播放）与音效系统是两条线：audio_players.dart 合法直用 audioplayers。
    final whitelist = {'lib/core/utils/sfx.dart', 'lib/core/audio/audio_players.dart'};
    final useRe = RegExp(r"import 'package:audioplayers/");

    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalized = entity.path.replaceAll('\\', '/');
        if (whitelist.contains(normalized)) continue;
        if (useRe.hasMatch(entity.readAsStringSync())) {
          violations.add(normalized);
        }
      }
    }
    expect(violations, isEmpty, reason: '音效（短反馈音）必须经 Sfx 门面收口；发音系统（audio_players）豁免——两条线不混');
  });

  test('音效资产与 Sfx 枚举一一对应', () {
    final dir = Directory('assets/sfx');
    expect(dir.existsSync(), isTrue, reason: 'assets/sfx/ 目录必须存在');
    final wavs = dir.listSync(recursive: true).whereType<File>().map((f) {
      final p = f.path.replaceAll('\\', '/');
      final idx = p.indexOf('assets/sfx/');
      return p.substring(idx + 'assets/sfx/'.length);
    }).toSet();

    final enumPaths = Sfx.values.map((s) => s.assetPath).toSet();
    expect(wavs.difference(enumPaths), isEmpty, reason: '有 wav 未注册进 Sfx 枚举：${wavs.difference(enumPaths)}');
    expect(enumPaths.difference(wavs), isEmpty, reason: 'Sfx 枚举引用了不存在的 wav：${enumPaths.difference(wavs)}');
  });

  test('音效总预算 ≤1MB（蓝图口径）', () {
    final dir = Directory('assets/sfx');
    final total = dir.listSync(recursive: true).whereType<File>().fold<int>(0, (sum, f) => sum + f.lengthSync());
    expect(total, lessThanOrEqualTo(1024 * 1024), reason: '音效超预算：${total / 1024}KB');
  });
}
