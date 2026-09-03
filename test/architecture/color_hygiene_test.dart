// M5（v2.7.43）：色彩卫生守卫——硬编码色字面量只允许出现在"定义处"。
//
// 背景（复审 A9/M5）：features 33 处 + widgets 58 处 Color(0x…) 字面量散落，
// 品牌色双写漂移、庆祝渐变两处各写一遍、错误态颜色不走主题（暗色失效）。
// v2.7.43 全部收口至 token 定义文件；本测试锁定成果：
// - 消费处（features/widgets/core/theme 除定义文件外）零 Color(0x 字面量；
// - 定义处白名单 = lib/tokens/** + skin_system.dart（preset 定义）+ wallpaper_data.dart（壁纸数据）；
// - 特效装饰色唯一入口 = lib/tokens/effect_palette.dart；
// - 庆祝渐变/彩纸调色板必须引共享常量，禁止组件内重写列表。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 颜色字面量的允许出现位置（"颜色的家"：token 定义与主题/壁纸数据定义）
const _whitelistPrefixes = <String>[
  'lib/tokens/', // 全部 token 定义（含 effect_palette.dart）
  'lib/theme/skin_system.dart', // 皮肤 preset 定义处（用户拍板豁免）
  'lib/theme/wallpaper_data.dart', // 壁纸颜色数据定义处
];

const _scanRoots = <String>['lib/features', 'lib/widgets', 'lib/core', 'lib/app', 'lib/theme'];

final _colorLiteralPattern = RegExp(r'Color\(0x[0-9a-fA-F]{8}\)');

void main() {
  group('M5 色彩卫生守卫', () {
    test('消费处零 Color(0x…) 字面量（定义处白名单除外）', () {
      final violations = <String>[];
      for (final root in _scanRoots) {
        final dir = Directory(root);
        if (!dir.existsSync()) continue;
        for (final f in dir.listSync(recursive: true).whereType<File>()) {
          if (!f.path.endsWith('.dart')) continue;
          final rel = f.path.replaceAll('\\', '/');
          if (_whitelistPrefixes.any(rel.startsWith)) continue;
          final lines = f.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            if (_colorLiteralPattern.hasMatch(lines[i])) {
              violations.add('$rel:${i + 1}: ${lines[i].trim()}');
            }
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            '发现硬编码色字面量——语义色请走 skin/FuncColors/MistralColors，'
            '品牌色引 StarbucksCreamColors，特效装饰色加到 lib/tokens/effect_palette.dart 并具名',
      );
    });

    test('effect_palette.dart 是特效装饰色唯一入口且全部具名', () {
      final source = File('lib/tokens/effect_palette.dart').readAsStringSync();
      // 白名单文件必须存在且承载特效调色板
      expect(source, contains('class PartyColors'));
      expect(source, contains('class GameBoyColors'));
      expect(source, contains('class MonsterPalette'));
      expect(source, contains('class GradientEffects'));
      // 渐变/彩纸列表必须引品牌常量或本文件具名色，禁止重新发明字面量组合
      expect(source, contains('static const List<Color> confetti'));
      expect(source, contains('static const List<Color> celebration'));
      expect(source, contains('static const List<Color> splash'));
      expect(source, contains('static const List<Color> liquidLogo'));
    });

    test('庆祝渐变/彩纸调色板消费方必须引共享常量（防双写复发）', () {
      final learn = File('lib/features/learning/presentation/learn_page.dart').readAsStringSync();
      final immersive = File('lib/features/learning/presentation/immersive_swipe_page.dart').readAsStringSync();
      final confetti = File('lib/widgets/confetti.dart').readAsStringSync();

      // learn_page 与 immersive_swipe 曾双写同一庆祝渐变（石山，A5 同类问题）
      expect(learn, contains('GradientEffects.celebration'));
      expect(immersive, contains('GradientEffects.celebration'));
      // confetti 两处发射列表曾双写 6 色调色板
      expect(confetti, contains('PartyColors.confetti'));
      expect(confetti, isNot(contains('Color(0x')));
    });

    test('品牌/阴影/三方品牌色 token 存在且被消费（收口成果非空转）', () {
      final starbucks = File('lib/tokens/starbucks_tokens.dart').readAsStringSync();
      final design = File('lib/tokens/design_tokens.dart').readAsStringSync();
      final func = File('lib/tokens/func_colors.dart').readAsStringSync();

      // starbucks_tokens：招牌绿中调（渐变专用）
      expect(starbucks, contains('greenSignature'));
      // design_tokens：阴影三档 + 第三方品牌色 + 错误边界色
      expect(design, contains('class MistralShadows'));
      expect(design, contains('class ThirdPartyBrand'));
      expect(design, contains('class ErrorBoundaryColors'));
      expect(design, contains('mutedGold'));
      // func_colors：业务语义色具名化
      expect(func, contains('streakFlame'));
      expect(func, contains('ratingStar'));
    });
  });
}
