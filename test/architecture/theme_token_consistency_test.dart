// 主题色单一事实来源守卫（审计 A1 / 上轮 M4）。
// 背景：v2.7.37 时代 skin_system 两套星巴克 preset 与 starbucks_tokens 双写硬编码，
// 色值已漂移（accent/success/danger/text2 等十余处）。v2.7.38 收敛：token 为唯一
// 定义点，preset 全字段引用常量。本测试锁定一致性——任何人重新硬编码分叉色值即测试失败。
// 豁免说明：其余 6 套皮肤（bright/dark/pure_black/warm_orange/claude 等）不对应
// token 集，不受本守卫约束。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/theme/skin_system.dart';
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
}
