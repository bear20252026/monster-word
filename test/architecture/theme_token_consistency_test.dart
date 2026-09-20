// 主题色单一事实来源守卫（审计 A1 / 上轮 M4 + batch7）。
// 星巴克→starbucks_tokens；其余 9 套→lib/tokens/skin_tokens.dart（本测试锁定）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/skin_tokens.dart';
import 'package:word_app/tokens/starbucks_tokens.dart';

void main() {
  group('主题色单一事实来源：星巴克 preset 必须等于 token', () {
    test('starbucks_cream 全字段 == StarbucksCreamColors', () {
      final vars = themes['starbucks_cream']!.vars;
      // 字段名 -> (preset 值, token 期望值)
      final pairs = <String, (Color, Color)>{
        'pageBg': (vars.pageBg, StarbucksCreamColors.pageBg),
        'cardBg': (vars.cardBg, StarbucksCreamColors.cardBg),
        'cardBgAlt': (vars.cardBgAlt, StarbucksCreamColors.cardBgAlt),
        'text1': (vars.text1, StarbucksCreamColors.text1),
        'text2': (vars.text2, StarbucksCreamColors.text2),
        'text3': (vars.text3, StarbucksCreamColors.text3),
        'divider': (vars.divider, StarbucksCreamColors.divider),
        'accent': (vars.accent, StarbucksCreamColors.accent),
        'success': (vars.success, StarbucksCreamColors.success),
        'danger': (vars.danger, StarbucksCreamColors.danger),
        'teal': (vars.teal, StarbucksCreamColors.teal),
        'tabBarIcon': (vars.tabBarIcon, StarbucksCreamColors.tabBarIcon),
        'onGlassText1': (vars.onGlassText1, StarbucksCreamColors.onGlassText1),
        'onGlassText2': (vars.onGlassText2, StarbucksCreamColors.onGlassText2),
        'onGlassAccent': (vars.onGlassAccent, StarbucksCreamColors.onGlassAccent),
        'glassBg': (vars.glassBg, StarbucksCreamColors.glassBg),
        'glassBgStrong': (vars.glassBgStrong, StarbucksCreamColors.glassBgStrong),
        'glassBorder': (vars.glassBorder, StarbucksCreamColors.glassBorder),
        'wallpaperScrim': (vars.wallpaperScrim, StarbucksCreamColors.wallpaperScrim),
        'modalGlassBg': (vars.modalGlassBg, StarbucksCreamColors.modalGlassBg),
        'modalText1': (vars.modalText1, StarbucksCreamColors.modalText1),
        'modalText2': (vars.modalText2, StarbucksCreamColors.modalText2),
        'quizCorrectBg': (vars.quizCorrectBg, StarbucksCreamColors.quizCorrectBg),
        'quizCorrectText': (vars.quizCorrectText, StarbucksCreamColors.quizCorrectText),
        'quizWrongBg': (vars.quizWrongBg, StarbucksCreamColors.quizWrongBg),
        'quizWrongText': (vars.quizWrongText, StarbucksCreamColors.quizWrongText),
        'vipGoldBg': (vars.vipGoldBg, StarbucksCreamColors.vipGoldBg),
        'vipGoldText': (vars.vipGoldText, StarbucksCreamColors.vipGoldText),
      };
      for (final entry in pairs.entries) {
        expect(entry.value.$1, entry.value.$2, reason: 'starbucks_cream.${entry.key} 与 token 漂移（单一事实来源被破坏）');
      }
      expect(
        vars.profileDecor,
        StarbucksCreamColors.profileDecor,
        reason: 'starbucks_cream.profileDecor 与 token 漂移（单一事实来源被破坏）',
      );
    });

    test('starbucks_dark 全字段 == StarbucksDarkColors', () {
      final vars = themes['starbucks_dark']!.vars;
      final pairs = <String, (Color, Color)>{
        'pageBg': (vars.pageBg, StarbucksDarkColors.pageBg),
        'cardBg': (vars.cardBg, StarbucksDarkColors.cardBg),
        'cardBgAlt': (vars.cardBgAlt, StarbucksDarkColors.cardBgAlt),
        'text1': (vars.text1, StarbucksDarkColors.text1),
        'text2': (vars.text2, StarbucksDarkColors.text2),
        'text3': (vars.text3, StarbucksDarkColors.text3),
        'divider': (vars.divider, StarbucksDarkColors.divider),
        'accent': (vars.accent, StarbucksDarkColors.accent),
        'success': (vars.success, StarbucksDarkColors.success),
        'danger': (vars.danger, StarbucksDarkColors.danger),
        'teal': (vars.teal, StarbucksDarkColors.teal),
        'tabBarIcon': (vars.tabBarIcon, StarbucksDarkColors.tabBarIcon),
        'onGlassText1': (vars.onGlassText1, StarbucksDarkColors.onGlassText1),
        'onGlassText2': (vars.onGlassText2, StarbucksDarkColors.onGlassText2),
        'onGlassAccent': (vars.onGlassAccent, StarbucksDarkColors.onGlassAccent),
        'glassBg': (vars.glassBg, StarbucksDarkColors.glassBg),
        'glassBgStrong': (vars.glassBgStrong, StarbucksDarkColors.glassBgStrong),
        'glassBorder': (vars.glassBorder, StarbucksDarkColors.glassBorder),
        'wallpaperScrim': (vars.wallpaperScrim, StarbucksDarkColors.wallpaperScrim),
        'modalGlassBg': (vars.modalGlassBg, StarbucksDarkColors.modalGlassBg),
        'modalText1': (vars.modalText1, StarbucksDarkColors.modalText1),
        'modalText2': (vars.modalText2, StarbucksDarkColors.modalText2),
        'quizCorrectBg': (vars.quizCorrectBg, StarbucksDarkColors.quizCorrectBg),
        'quizCorrectText': (vars.quizCorrectText, StarbucksDarkColors.quizCorrectText),
        'quizWrongBg': (vars.quizWrongBg, StarbucksDarkColors.quizWrongBg),
        'quizWrongText': (vars.quizWrongText, StarbucksDarkColors.quizWrongText),
        'vipGoldBg': (vars.vipGoldBg, StarbucksDarkColors.vipGoldBg),
        'vipGoldText': (vars.vipGoldText, StarbucksDarkColors.vipGoldText),
      };
      for (final entry in pairs.entries) {
        expect(entry.value.$1, entry.value.$2, reason: 'starbucks_dark.${entry.key} 与 token 漂移（单一事实来源被破坏）');
      }
      expect(
        vars.profileDecor,
        StarbucksDarkColors.profileDecor,
        reason: 'starbucks_dark.profileDecor 与 token 漂移（单一事实来源被破坏）',
      );
    });

    test('WCAG 修正值抽查：品牌绿/成功/危险为统一深色值', () {
      // 锁定本轮拍板的 WCAG 修正值，防止回退到旧分叉值
      expect(StarbucksCreamColors.greenBrand, const Color(0xFF006B3F));
      expect(StarbucksCreamColors.accent, const Color(0xFF006B3F));
      expect(StarbucksCreamColors.success, const Color(0xFF2E7D32));
      expect(StarbucksCreamColors.danger, const Color(0xFFBF2020));
      expect(StarbucksDarkColors.accent, const Color(0xFF00BB00));
      expect(StarbucksDarkColors.success, const Color(0xFF00C853));
      expect(StarbucksDarkColors.danger, const Color(0xFFFF5252));
    });
  });

  group('皮肤 token 单一事实来源（batch7：9 套非星巴克）', () {
    test('preset 字段 == skin_tokens 常量', () {
      Color pick(String field, ThemeVars vars) {
        return switch (field) {
          'pageBg' => vars.pageBg,
          'cardBg' => vars.cardBg,
          'cardBgAlt' => vars.cardBgAlt,
          'text1' => vars.text1,
          'text2' => vars.text2,
          'text3' => vars.text3,
          'divider' => vars.divider,
          'accent' => vars.accent,
          'success' => vars.success,
          'danger' => vars.danger,
          'teal' => vars.teal,
          'tabBarIcon' => vars.tabBarIcon,
          'onGlassText1' => vars.onGlassText1,
          'onGlassText2' => vars.onGlassText2,
          'onGlassAccent' => vars.onGlassAccent,
          'glassBg' => vars.glassBg,
          'glassBgStrong' => vars.glassBgStrong,
          'glassBorder' => vars.glassBorder,
          'wallpaperScrim' => vars.wallpaperScrim,
          'modalGlassBg' => vars.modalGlassBg,
          'modalText1' => vars.modalText1,
          'modalText2' => vars.modalText2,
          'quizCorrectBg' => vars.quizCorrectBg,
          'quizCorrectText' => vars.quizCorrectText,
          'quizWrongBg' => vars.quizWrongBg,
          'quizWrongText' => vars.quizWrongText,
          'vipGoldBg' => vars.vipGoldBg,
          'vipGoldText' => vars.vipGoldText,
          _ => throw ArgumentError(field),
        };
      }

      expect(pick('pageBg', themes['bright']!.vars), BrightThemeColors.pageBg, reason: 'bright.pageBg');
      expect(pick('cardBg', themes['bright']!.vars), BrightThemeColors.cardBg, reason: 'bright.cardBg');
      expect(pick('cardBgAlt', themes['bright']!.vars), BrightThemeColors.cardBgAlt, reason: 'bright.cardBgAlt');
      expect(pick('text1', themes['bright']!.vars), BrightThemeColors.text1, reason: 'bright.text1');
      expect(pick('text2', themes['bright']!.vars), BrightThemeColors.text2, reason: 'bright.text2');
      expect(pick('text3', themes['bright']!.vars), BrightThemeColors.text3, reason: 'bright.text3');
      expect(pick('divider', themes['bright']!.vars), BrightThemeColors.divider, reason: 'bright.divider');
      expect(pick('accent', themes['bright']!.vars), BrightThemeColors.accent, reason: 'bright.accent');
      expect(pick('success', themes['bright']!.vars), BrightThemeColors.success, reason: 'bright.success');
      expect(pick('danger', themes['bright']!.vars), BrightThemeColors.danger, reason: 'bright.danger');
      expect(pick('teal', themes['bright']!.vars), BrightThemeColors.teal, reason: 'bright.teal');
      expect(pick('tabBarIcon', themes['bright']!.vars), BrightThemeColors.tabBarIcon, reason: 'bright.tabBarIcon');
      expect(
        pick('quizCorrectBg', themes['bright']!.vars),
        BrightThemeColors.quizCorrectBg,
        reason: 'bright.quizCorrectBg',
      );
      expect(
        pick('quizCorrectText', themes['bright']!.vars),
        BrightThemeColors.quizCorrectText,
        reason: 'bright.quizCorrectText',
      );
      expect(pick('quizWrongBg', themes['bright']!.vars), BrightThemeColors.quizWrongBg, reason: 'bright.quizWrongBg');
      expect(
        pick('quizWrongText', themes['bright']!.vars),
        BrightThemeColors.quizWrongText,
        reason: 'bright.quizWrongText',
      );
      expect(pick('pageBg', themes['dark']!.vars), DarkThemeColors.pageBg, reason: 'dark.pageBg');
      expect(pick('cardBg', themes['dark']!.vars), DarkThemeColors.cardBg, reason: 'dark.cardBg');
      expect(pick('cardBgAlt', themes['dark']!.vars), DarkThemeColors.cardBgAlt, reason: 'dark.cardBgAlt');
      expect(pick('text1', themes['dark']!.vars), DarkThemeColors.text1, reason: 'dark.text1');
      expect(pick('text2', themes['dark']!.vars), DarkThemeColors.text2, reason: 'dark.text2');
      expect(pick('text3', themes['dark']!.vars), DarkThemeColors.text3, reason: 'dark.text3');
      expect(pick('divider', themes['dark']!.vars), DarkThemeColors.divider, reason: 'dark.divider');
      expect(pick('accent', themes['dark']!.vars), DarkThemeColors.accent, reason: 'dark.accent');
      expect(pick('success', themes['dark']!.vars), DarkThemeColors.success, reason: 'dark.success');
      expect(pick('danger', themes['dark']!.vars), DarkThemeColors.danger, reason: 'dark.danger');
      expect(pick('teal', themes['dark']!.vars), DarkThemeColors.teal, reason: 'dark.teal');
      expect(pick('tabBarIcon', themes['dark']!.vars), DarkThemeColors.tabBarIcon, reason: 'dark.tabBarIcon');
      expect(pick('onGlassText1', themes['dark']!.vars), DarkThemeColors.onGlassText1, reason: 'dark.onGlassText1');
      expect(pick('onGlassText2', themes['dark']!.vars), DarkThemeColors.onGlassText2, reason: 'dark.onGlassText2');
      expect(pick('onGlassAccent', themes['dark']!.vars), DarkThemeColors.onGlassAccent, reason: 'dark.onGlassAccent');
      expect(pick('quizCorrectBg', themes['dark']!.vars), DarkThemeColors.quizCorrectBg, reason: 'dark.quizCorrectBg');
      expect(
        pick('quizCorrectText', themes['dark']!.vars),
        DarkThemeColors.quizCorrectText,
        reason: 'dark.quizCorrectText',
      );
      expect(pick('quizWrongBg', themes['dark']!.vars), DarkThemeColors.quizWrongBg, reason: 'dark.quizWrongBg');
      expect(pick('quizWrongText', themes['dark']!.vars), DarkThemeColors.quizWrongText, reason: 'dark.quizWrongText');
      expect(pick('pageBg', themes['pure_black']!.vars), PureBlackThemeColors.pageBg, reason: 'pure_black.pageBg');
      expect(pick('cardBg', themes['pure_black']!.vars), PureBlackThemeColors.cardBg, reason: 'pure_black.cardBg');
      expect(
        pick('cardBgAlt', themes['pure_black']!.vars),
        PureBlackThemeColors.cardBgAlt,
        reason: 'pure_black.cardBgAlt',
      );
      expect(pick('text1', themes['pure_black']!.vars), PureBlackThemeColors.text1, reason: 'pure_black.text1');
      expect(pick('text2', themes['pure_black']!.vars), PureBlackThemeColors.text2, reason: 'pure_black.text2');
      expect(pick('text3', themes['pure_black']!.vars), PureBlackThemeColors.text3, reason: 'pure_black.text3');
      expect(pick('divider', themes['pure_black']!.vars), PureBlackThemeColors.divider, reason: 'pure_black.divider');
      expect(pick('accent', themes['pure_black']!.vars), PureBlackThemeColors.accent, reason: 'pure_black.accent');
      expect(pick('success', themes['pure_black']!.vars), PureBlackThemeColors.success, reason: 'pure_black.success');
      expect(pick('danger', themes['pure_black']!.vars), PureBlackThemeColors.danger, reason: 'pure_black.danger');
      expect(pick('teal', themes['pure_black']!.vars), PureBlackThemeColors.teal, reason: 'pure_black.teal');
      expect(
        pick('tabBarIcon', themes['pure_black']!.vars),
        PureBlackThemeColors.tabBarIcon,
        reason: 'pure_black.tabBarIcon',
      );
      expect(
        pick('onGlassText1', themes['pure_black']!.vars),
        PureBlackThemeColors.onGlassText1,
        reason: 'pure_black.onGlassText1',
      );
      expect(
        pick('onGlassText2', themes['pure_black']!.vars),
        PureBlackThemeColors.onGlassText2,
        reason: 'pure_black.onGlassText2',
      );
      expect(
        pick('onGlassAccent', themes['pure_black']!.vars),
        PureBlackThemeColors.onGlassAccent,
        reason: 'pure_black.onGlassAccent',
      );
      expect(
        pick('quizCorrectBg', themes['pure_black']!.vars),
        PureBlackThemeColors.quizCorrectBg,
        reason: 'pure_black.quizCorrectBg',
      );
      expect(
        pick('quizCorrectText', themes['pure_black']!.vars),
        PureBlackThemeColors.quizCorrectText,
        reason: 'pure_black.quizCorrectText',
      );
      expect(
        pick('quizWrongBg', themes['pure_black']!.vars),
        PureBlackThemeColors.quizWrongBg,
        reason: 'pure_black.quizWrongBg',
      );
      expect(
        pick('quizWrongText', themes['pure_black']!.vars),
        PureBlackThemeColors.quizWrongText,
        reason: 'pure_black.quizWrongText',
      );
      expect(pick('pageBg', themes['warm_orange']!.vars), WarmOrangeThemeColors.pageBg, reason: 'warm_orange.pageBg');
      expect(pick('cardBg', themes['warm_orange']!.vars), WarmOrangeThemeColors.cardBg, reason: 'warm_orange.cardBg');
      expect(
        pick('cardBgAlt', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.cardBgAlt,
        reason: 'warm_orange.cardBgAlt',
      );
      expect(pick('text1', themes['warm_orange']!.vars), WarmOrangeThemeColors.text1, reason: 'warm_orange.text1');
      expect(pick('text2', themes['warm_orange']!.vars), WarmOrangeThemeColors.text2, reason: 'warm_orange.text2');
      expect(pick('text3', themes['warm_orange']!.vars), WarmOrangeThemeColors.text3, reason: 'warm_orange.text3');
      expect(
        pick('divider', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.divider,
        reason: 'warm_orange.divider',
      );
      expect(pick('accent', themes['warm_orange']!.vars), WarmOrangeThemeColors.accent, reason: 'warm_orange.accent');
      expect(
        pick('success', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.success,
        reason: 'warm_orange.success',
      );
      expect(pick('danger', themes['warm_orange']!.vars), WarmOrangeThemeColors.danger, reason: 'warm_orange.danger');
      expect(pick('teal', themes['warm_orange']!.vars), WarmOrangeThemeColors.teal, reason: 'warm_orange.teal');
      expect(
        pick('tabBarIcon', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.tabBarIcon,
        reason: 'warm_orange.tabBarIcon',
      );
      expect(
        pick('onGlassText1', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.onGlassText1,
        reason: 'warm_orange.onGlassText1',
      );
      expect(
        pick('onGlassText2', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.onGlassText2,
        reason: 'warm_orange.onGlassText2',
      );
      expect(
        pick('onGlassAccent', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.onGlassAccent,
        reason: 'warm_orange.onGlassAccent',
      );
      expect(
        pick('glassBg', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.glassBg,
        reason: 'warm_orange.glassBg',
      );
      expect(
        pick('glassBgStrong', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.glassBgStrong,
        reason: 'warm_orange.glassBgStrong',
      );
      expect(
        pick('glassBorder', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.glassBorder,
        reason: 'warm_orange.glassBorder',
      );
      expect(
        pick('wallpaperScrim', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.wallpaperScrim,
        reason: 'warm_orange.wallpaperScrim',
      );
      expect(
        pick('modalGlassBg', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.modalGlassBg,
        reason: 'warm_orange.modalGlassBg',
      );
      expect(
        pick('modalText1', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.modalText1,
        reason: 'warm_orange.modalText1',
      );
      expect(
        pick('modalText2', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.modalText2,
        reason: 'warm_orange.modalText2',
      );
      expect(
        pick('quizCorrectBg', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.quizCorrectBg,
        reason: 'warm_orange.quizCorrectBg',
      );
      expect(
        pick('quizCorrectText', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.quizCorrectText,
        reason: 'warm_orange.quizCorrectText',
      );
      expect(
        pick('quizWrongBg', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.quizWrongBg,
        reason: 'warm_orange.quizWrongBg',
      );
      expect(
        pick('quizWrongText', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.quizWrongText,
        reason: 'warm_orange.quizWrongText',
      );
      expect(
        pick('vipGoldBg', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.vipGoldBg,
        reason: 'warm_orange.vipGoldBg',
      );
      expect(
        pick('vipGoldText', themes['warm_orange']!.vars),
        WarmOrangeThemeColors.vipGoldText,
        reason: 'warm_orange.vipGoldText',
      );
      expect(pick('pageBg', themes['claude_cream']!.vars), ClaudeCreamColors.pageBg, reason: 'claude_cream.pageBg');
      expect(pick('cardBg', themes['claude_cream']!.vars), ClaudeCreamColors.cardBg, reason: 'claude_cream.cardBg');
      expect(
        pick('cardBgAlt', themes['claude_cream']!.vars),
        ClaudeCreamColors.cardBgAlt,
        reason: 'claude_cream.cardBgAlt',
      );
      expect(pick('text1', themes['claude_cream']!.vars), ClaudeCreamColors.text1, reason: 'claude_cream.text1');
      expect(pick('text2', themes['claude_cream']!.vars), ClaudeCreamColors.text2, reason: 'claude_cream.text2');
      expect(pick('text3', themes['claude_cream']!.vars), ClaudeCreamColors.text3, reason: 'claude_cream.text3');
      expect(pick('divider', themes['claude_cream']!.vars), ClaudeCreamColors.divider, reason: 'claude_cream.divider');
      expect(pick('accent', themes['claude_cream']!.vars), ClaudeCreamColors.accent, reason: 'claude_cream.accent');
      expect(pick('success', themes['claude_cream']!.vars), ClaudeCreamColors.success, reason: 'claude_cream.success');
      expect(pick('danger', themes['claude_cream']!.vars), ClaudeCreamColors.danger, reason: 'claude_cream.danger');
      expect(pick('teal', themes['claude_cream']!.vars), ClaudeCreamColors.teal, reason: 'claude_cream.teal');
      expect(
        pick('tabBarIcon', themes['claude_cream']!.vars),
        ClaudeCreamColors.tabBarIcon,
        reason: 'claude_cream.tabBarIcon',
      );
      expect(
        pick('onGlassText1', themes['claude_cream']!.vars),
        ClaudeCreamColors.onGlassText1,
        reason: 'claude_cream.onGlassText1',
      );
      expect(
        pick('onGlassText2', themes['claude_cream']!.vars),
        ClaudeCreamColors.onGlassText2,
        reason: 'claude_cream.onGlassText2',
      );
      expect(
        pick('onGlassAccent', themes['claude_cream']!.vars),
        ClaudeCreamColors.onGlassAccent,
        reason: 'claude_cream.onGlassAccent',
      );
      expect(pick('glassBg', themes['claude_cream']!.vars), ClaudeCreamColors.glassBg, reason: 'claude_cream.glassBg');
      expect(
        pick('glassBgStrong', themes['claude_cream']!.vars),
        ClaudeCreamColors.glassBgStrong,
        reason: 'claude_cream.glassBgStrong',
      );
      expect(
        pick('glassBorder', themes['claude_cream']!.vars),
        ClaudeCreamColors.glassBorder,
        reason: 'claude_cream.glassBorder',
      );
      expect(
        pick('wallpaperScrim', themes['claude_cream']!.vars),
        ClaudeCreamColors.wallpaperScrim,
        reason: 'claude_cream.wallpaperScrim',
      );
      expect(
        pick('modalGlassBg', themes['claude_cream']!.vars),
        ClaudeCreamColors.modalGlassBg,
        reason: 'claude_cream.modalGlassBg',
      );
      expect(
        pick('modalText1', themes['claude_cream']!.vars),
        ClaudeCreamColors.modalText1,
        reason: 'claude_cream.modalText1',
      );
      expect(
        pick('modalText2', themes['claude_cream']!.vars),
        ClaudeCreamColors.modalText2,
        reason: 'claude_cream.modalText2',
      );
      expect(
        pick('quizCorrectBg', themes['claude_cream']!.vars),
        ClaudeCreamColors.quizCorrectBg,
        reason: 'claude_cream.quizCorrectBg',
      );
      expect(
        pick('quizCorrectText', themes['claude_cream']!.vars),
        ClaudeCreamColors.quizCorrectText,
        reason: 'claude_cream.quizCorrectText',
      );
      expect(
        pick('quizWrongBg', themes['claude_cream']!.vars),
        ClaudeCreamColors.quizWrongBg,
        reason: 'claude_cream.quizWrongBg',
      );
      expect(
        pick('quizWrongText', themes['claude_cream']!.vars),
        ClaudeCreamColors.quizWrongText,
        reason: 'claude_cream.quizWrongText',
      );
      expect(
        pick('vipGoldBg', themes['claude_cream']!.vars),
        ClaudeCreamColors.vipGoldBg,
        reason: 'claude_cream.vipGoldBg',
      );
      expect(
        pick('vipGoldText', themes['claude_cream']!.vars),
        ClaudeCreamColors.vipGoldText,
        reason: 'claude_cream.vipGoldText',
      );
      expect(pick('pageBg', themes['airbnb_light']!.vars), AirbnbLightColors.pageBg, reason: 'airbnb_light.pageBg');
      expect(pick('cardBg', themes['airbnb_light']!.vars), AirbnbLightColors.cardBg, reason: 'airbnb_light.cardBg');
      expect(
        pick('cardBgAlt', themes['airbnb_light']!.vars),
        AirbnbLightColors.cardBgAlt,
        reason: 'airbnb_light.cardBgAlt',
      );
      expect(pick('text1', themes['airbnb_light']!.vars), AirbnbLightColors.text1, reason: 'airbnb_light.text1');
      expect(pick('text2', themes['airbnb_light']!.vars), AirbnbLightColors.text2, reason: 'airbnb_light.text2');
      expect(pick('text3', themes['airbnb_light']!.vars), AirbnbLightColors.text3, reason: 'airbnb_light.text3');
      expect(pick('divider', themes['airbnb_light']!.vars), AirbnbLightColors.divider, reason: 'airbnb_light.divider');
      expect(pick('accent', themes['airbnb_light']!.vars), AirbnbLightColors.accent, reason: 'airbnb_light.accent');
      expect(pick('success', themes['airbnb_light']!.vars), AirbnbLightColors.success, reason: 'airbnb_light.success');
      expect(pick('danger', themes['airbnb_light']!.vars), AirbnbLightColors.danger, reason: 'airbnb_light.danger');
      expect(pick('teal', themes['airbnb_light']!.vars), AirbnbLightColors.teal, reason: 'airbnb_light.teal');
      expect(
        pick('tabBarIcon', themes['airbnb_light']!.vars),
        AirbnbLightColors.tabBarIcon,
        reason: 'airbnb_light.tabBarIcon',
      );
      expect(
        pick('onGlassText1', themes['airbnb_light']!.vars),
        AirbnbLightColors.onGlassText1,
        reason: 'airbnb_light.onGlassText1',
      );
      expect(
        pick('onGlassText2', themes['airbnb_light']!.vars),
        AirbnbLightColors.onGlassText2,
        reason: 'airbnb_light.onGlassText2',
      );
      expect(
        pick('onGlassAccent', themes['airbnb_light']!.vars),
        AirbnbLightColors.onGlassAccent,
        reason: 'airbnb_light.onGlassAccent',
      );
      expect(pick('glassBg', themes['airbnb_light']!.vars), AirbnbLightColors.glassBg, reason: 'airbnb_light.glassBg');
      expect(
        pick('glassBgStrong', themes['airbnb_light']!.vars),
        AirbnbLightColors.glassBgStrong,
        reason: 'airbnb_light.glassBgStrong',
      );
      expect(
        pick('glassBorder', themes['airbnb_light']!.vars),
        AirbnbLightColors.glassBorder,
        reason: 'airbnb_light.glassBorder',
      );
      expect(
        pick('wallpaperScrim', themes['airbnb_light']!.vars),
        AirbnbLightColors.wallpaperScrim,
        reason: 'airbnb_light.wallpaperScrim',
      );
      expect(
        pick('modalGlassBg', themes['airbnb_light']!.vars),
        AirbnbLightColors.modalGlassBg,
        reason: 'airbnb_light.modalGlassBg',
      );
      expect(
        pick('modalText1', themes['airbnb_light']!.vars),
        AirbnbLightColors.modalText1,
        reason: 'airbnb_light.modalText1',
      );
      expect(
        pick('modalText2', themes['airbnb_light']!.vars),
        AirbnbLightColors.modalText2,
        reason: 'airbnb_light.modalText2',
      );
      expect(
        pick('quizCorrectBg', themes['airbnb_light']!.vars),
        AirbnbLightColors.quizCorrectBg,
        reason: 'airbnb_light.quizCorrectBg',
      );
      expect(
        pick('quizCorrectText', themes['airbnb_light']!.vars),
        AirbnbLightColors.quizCorrectText,
        reason: 'airbnb_light.quizCorrectText',
      );
      expect(
        pick('quizWrongBg', themes['airbnb_light']!.vars),
        AirbnbLightColors.quizWrongBg,
        reason: 'airbnb_light.quizWrongBg',
      );
      expect(
        pick('quizWrongText', themes['airbnb_light']!.vars),
        AirbnbLightColors.quizWrongText,
        reason: 'airbnb_light.quizWrongText',
      );
      expect(
        pick('vipGoldBg', themes['airbnb_light']!.vars),
        AirbnbLightColors.vipGoldBg,
        reason: 'airbnb_light.vipGoldBg',
      );
      expect(
        pick('vipGoldText', themes['airbnb_light']!.vars),
        AirbnbLightColors.vipGoldText,
        reason: 'airbnb_light.vipGoldText',
      );
      expect(pick('pageBg', themes['nike_mono']!.vars), NikeMonoColors.pageBg, reason: 'nike_mono.pageBg');
      expect(pick('cardBg', themes['nike_mono']!.vars), NikeMonoColors.cardBg, reason: 'nike_mono.cardBg');
      expect(pick('cardBgAlt', themes['nike_mono']!.vars), NikeMonoColors.cardBgAlt, reason: 'nike_mono.cardBgAlt');
      expect(pick('text1', themes['nike_mono']!.vars), NikeMonoColors.text1, reason: 'nike_mono.text1');
      expect(pick('text2', themes['nike_mono']!.vars), NikeMonoColors.text2, reason: 'nike_mono.text2');
      expect(pick('text3', themes['nike_mono']!.vars), NikeMonoColors.text3, reason: 'nike_mono.text3');
      expect(pick('divider', themes['nike_mono']!.vars), NikeMonoColors.divider, reason: 'nike_mono.divider');
      expect(pick('accent', themes['nike_mono']!.vars), NikeMonoColors.accent, reason: 'nike_mono.accent');
      expect(pick('success', themes['nike_mono']!.vars), NikeMonoColors.success, reason: 'nike_mono.success');
      expect(pick('danger', themes['nike_mono']!.vars), NikeMonoColors.danger, reason: 'nike_mono.danger');
      expect(pick('teal', themes['nike_mono']!.vars), NikeMonoColors.teal, reason: 'nike_mono.teal');
      expect(pick('tabBarIcon', themes['nike_mono']!.vars), NikeMonoColors.tabBarIcon, reason: 'nike_mono.tabBarIcon');
      expect(
        pick('onGlassText1', themes['nike_mono']!.vars),
        NikeMonoColors.onGlassText1,
        reason: 'nike_mono.onGlassText1',
      );
      expect(
        pick('onGlassText2', themes['nike_mono']!.vars),
        NikeMonoColors.onGlassText2,
        reason: 'nike_mono.onGlassText2',
      );
      expect(
        pick('onGlassAccent', themes['nike_mono']!.vars),
        NikeMonoColors.onGlassAccent,
        reason: 'nike_mono.onGlassAccent',
      );
      expect(pick('glassBg', themes['nike_mono']!.vars), NikeMonoColors.glassBg, reason: 'nike_mono.glassBg');
      expect(
        pick('glassBgStrong', themes['nike_mono']!.vars),
        NikeMonoColors.glassBgStrong,
        reason: 'nike_mono.glassBgStrong',
      );
      expect(
        pick('glassBorder', themes['nike_mono']!.vars),
        NikeMonoColors.glassBorder,
        reason: 'nike_mono.glassBorder',
      );
      expect(
        pick('wallpaperScrim', themes['nike_mono']!.vars),
        NikeMonoColors.wallpaperScrim,
        reason: 'nike_mono.wallpaperScrim',
      );
      expect(
        pick('modalGlassBg', themes['nike_mono']!.vars),
        NikeMonoColors.modalGlassBg,
        reason: 'nike_mono.modalGlassBg',
      );
      expect(pick('modalText1', themes['nike_mono']!.vars), NikeMonoColors.modalText1, reason: 'nike_mono.modalText1');
      expect(pick('modalText2', themes['nike_mono']!.vars), NikeMonoColors.modalText2, reason: 'nike_mono.modalText2');
      expect(
        pick('quizCorrectBg', themes['nike_mono']!.vars),
        NikeMonoColors.quizCorrectBg,
        reason: 'nike_mono.quizCorrectBg',
      );
      expect(
        pick('quizCorrectText', themes['nike_mono']!.vars),
        NikeMonoColors.quizCorrectText,
        reason: 'nike_mono.quizCorrectText',
      );
      expect(
        pick('quizWrongBg', themes['nike_mono']!.vars),
        NikeMonoColors.quizWrongBg,
        reason: 'nike_mono.quizWrongBg',
      );
      expect(
        pick('quizWrongText', themes['nike_mono']!.vars),
        NikeMonoColors.quizWrongText,
        reason: 'nike_mono.quizWrongText',
      );
      expect(pick('vipGoldBg', themes['nike_mono']!.vars), NikeMonoColors.vipGoldBg, reason: 'nike_mono.vipGoldBg');
      expect(
        pick('vipGoldText', themes['nike_mono']!.vars),
        NikeMonoColors.vipGoldText,
        reason: 'nike_mono.vipGoldText',
      );
      expect(pick('pageBg', themes['apple_light']!.vars), AppleLightColors.pageBg, reason: 'apple_light.pageBg');
      expect(pick('cardBg', themes['apple_light']!.vars), AppleLightColors.cardBg, reason: 'apple_light.cardBg');
      expect(
        pick('cardBgAlt', themes['apple_light']!.vars),
        AppleLightColors.cardBgAlt,
        reason: 'apple_light.cardBgAlt',
      );
      expect(pick('text1', themes['apple_light']!.vars), AppleLightColors.text1, reason: 'apple_light.text1');
      expect(pick('text2', themes['apple_light']!.vars), AppleLightColors.text2, reason: 'apple_light.text2');
      expect(pick('text3', themes['apple_light']!.vars), AppleLightColors.text3, reason: 'apple_light.text3');
      expect(pick('divider', themes['apple_light']!.vars), AppleLightColors.divider, reason: 'apple_light.divider');
      expect(pick('accent', themes['apple_light']!.vars), AppleLightColors.accent, reason: 'apple_light.accent');
      expect(pick('success', themes['apple_light']!.vars), AppleLightColors.success, reason: 'apple_light.success');
      expect(pick('danger', themes['apple_light']!.vars), AppleLightColors.danger, reason: 'apple_light.danger');
      expect(pick('teal', themes['apple_light']!.vars), AppleLightColors.teal, reason: 'apple_light.teal');
      expect(
        pick('tabBarIcon', themes['apple_light']!.vars),
        AppleLightColors.tabBarIcon,
        reason: 'apple_light.tabBarIcon',
      );
      expect(
        pick('onGlassText1', themes['apple_light']!.vars),
        AppleLightColors.onGlassText1,
        reason: 'apple_light.onGlassText1',
      );
      expect(
        pick('onGlassText2', themes['apple_light']!.vars),
        AppleLightColors.onGlassText2,
        reason: 'apple_light.onGlassText2',
      );
      expect(
        pick('onGlassAccent', themes['apple_light']!.vars),
        AppleLightColors.onGlassAccent,
        reason: 'apple_light.onGlassAccent',
      );
      expect(pick('glassBg', themes['apple_light']!.vars), AppleLightColors.glassBg, reason: 'apple_light.glassBg');
      expect(
        pick('glassBgStrong', themes['apple_light']!.vars),
        AppleLightColors.glassBgStrong,
        reason: 'apple_light.glassBgStrong',
      );
      expect(
        pick('glassBorder', themes['apple_light']!.vars),
        AppleLightColors.glassBorder,
        reason: 'apple_light.glassBorder',
      );
      expect(
        pick('wallpaperScrim', themes['apple_light']!.vars),
        AppleLightColors.wallpaperScrim,
        reason: 'apple_light.wallpaperScrim',
      );
      expect(
        pick('modalGlassBg', themes['apple_light']!.vars),
        AppleLightColors.modalGlassBg,
        reason: 'apple_light.modalGlassBg',
      );
      expect(
        pick('modalText1', themes['apple_light']!.vars),
        AppleLightColors.modalText1,
        reason: 'apple_light.modalText1',
      );
      expect(
        pick('modalText2', themes['apple_light']!.vars),
        AppleLightColors.modalText2,
        reason: 'apple_light.modalText2',
      );
      expect(
        pick('quizCorrectBg', themes['apple_light']!.vars),
        AppleLightColors.quizCorrectBg,
        reason: 'apple_light.quizCorrectBg',
      );
      expect(
        pick('quizCorrectText', themes['apple_light']!.vars),
        AppleLightColors.quizCorrectText,
        reason: 'apple_light.quizCorrectText',
      );
      expect(
        pick('quizWrongBg', themes['apple_light']!.vars),
        AppleLightColors.quizWrongBg,
        reason: 'apple_light.quizWrongBg',
      );
      expect(
        pick('quizWrongText', themes['apple_light']!.vars),
        AppleLightColors.quizWrongText,
        reason: 'apple_light.quizWrongText',
      );
      expect(
        pick('vipGoldBg', themes['apple_light']!.vars),
        AppleLightColors.vipGoldBg,
        reason: 'apple_light.vipGoldBg',
      );
      expect(
        pick('vipGoldText', themes['apple_light']!.vars),
        AppleLightColors.vipGoldText,
        reason: 'apple_light.vipGoldText',
      );
      expect(
        pick('pageBg', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.pageBg,
        reason: 'clickhouse_dark.pageBg',
      );
      expect(
        pick('cardBg', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.cardBg,
        reason: 'clickhouse_dark.cardBg',
      );
      expect(
        pick('cardBgAlt', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.cardBgAlt,
        reason: 'clickhouse_dark.cardBgAlt',
      );
      expect(
        pick('text1', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.text1,
        reason: 'clickhouse_dark.text1',
      );
      expect(
        pick('text2', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.text2,
        reason: 'clickhouse_dark.text2',
      );
      expect(
        pick('text3', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.text3,
        reason: 'clickhouse_dark.text3',
      );
      expect(
        pick('divider', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.divider,
        reason: 'clickhouse_dark.divider',
      );
      expect(
        pick('accent', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.accent,
        reason: 'clickhouse_dark.accent',
      );
      expect(
        pick('success', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.success,
        reason: 'clickhouse_dark.success',
      );
      expect(
        pick('danger', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.danger,
        reason: 'clickhouse_dark.danger',
      );
      expect(pick('teal', themes['clickhouse_dark']!.vars), ClickhouseDarkColors.teal, reason: 'clickhouse_dark.teal');
      expect(
        pick('tabBarIcon', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.tabBarIcon,
        reason: 'clickhouse_dark.tabBarIcon',
      );
      expect(
        pick('onGlassText1', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.onGlassText1,
        reason: 'clickhouse_dark.onGlassText1',
      );
      expect(
        pick('onGlassText2', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.onGlassText2,
        reason: 'clickhouse_dark.onGlassText2',
      );
      expect(
        pick('onGlassAccent', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.onGlassAccent,
        reason: 'clickhouse_dark.onGlassAccent',
      );
      expect(
        pick('glassBg', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.glassBg,
        reason: 'clickhouse_dark.glassBg',
      );
      expect(
        pick('glassBgStrong', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.glassBgStrong,
        reason: 'clickhouse_dark.glassBgStrong',
      );
      expect(
        pick('glassBorder', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.glassBorder,
        reason: 'clickhouse_dark.glassBorder',
      );
      expect(
        pick('wallpaperScrim', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.wallpaperScrim,
        reason: 'clickhouse_dark.wallpaperScrim',
      );
      expect(
        pick('modalGlassBg', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.modalGlassBg,
        reason: 'clickhouse_dark.modalGlassBg',
      );
      expect(
        pick('modalText1', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.modalText1,
        reason: 'clickhouse_dark.modalText1',
      );
      expect(
        pick('modalText2', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.modalText2,
        reason: 'clickhouse_dark.modalText2',
      );
      expect(
        pick('quizCorrectBg', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.quizCorrectBg,
        reason: 'clickhouse_dark.quizCorrectBg',
      );
      expect(
        pick('quizCorrectText', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.quizCorrectText,
        reason: 'clickhouse_dark.quizCorrectText',
      );
      expect(
        pick('quizWrongBg', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.quizWrongBg,
        reason: 'clickhouse_dark.quizWrongBg',
      );
      expect(
        pick('quizWrongText', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.quizWrongText,
        reason: 'clickhouse_dark.quizWrongText',
      );
      expect(
        pick('vipGoldBg', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.vipGoldBg,
        reason: 'clickhouse_dark.vipGoldBg',
      );
      expect(
        pick('vipGoldText', themes['clickhouse_dark']!.vars),
        ClickhouseDarkColors.vipGoldText,
        reason: 'clickhouse_dark.vipGoldText',
      );
    });
  });
}
