// Monster Word — 语义颜色变量（ThemeVars / ThemeSummary）。
// 从 skin_system.dart 拆出（788 行文件治理，2026-09）。

import 'package:flutter/material.dart';

class ThemeVars {
  final Color pageBg;
  final Color cardBg;
  final Color cardBgAlt;
  final Color text1;
  final Color text2;
  final Color text3;
  final Color divider;
  final Color accent;
  final Color success;
  final Color danger;
  final Color teal;
  final Color tabBarIcon;
  // 兼容字段
  final Color onGlassText1;
  final Color onGlassText2;
  final Color onGlassAccent;
  final Color glassBg;
  final Color glassBgStrong;
  final Color glassBorder;
  final Color wallpaperScrim;
  final Color modalGlassBg;
  final Color modalText1;
  final Color modalText2;
  final Color quizCorrectBg;
  final Color quizCorrectText;
  final Color quizWrongBg;
  final Color quizWrongText;
  final Color vipGoldBg;
  final Color vipGoldText;
  final List<Color> profileDecor;

  ThemeVars({
    required this.pageBg,
    required this.cardBg,
    required this.cardBgAlt,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.divider,
    required this.accent,
    required this.success,
    required this.danger,
    required this.teal,
    required this.tabBarIcon,
    Color? onGlassText1,
    Color? onGlassText2,
    Color? onGlassAccent,
    Color? glassBg,
    Color? glassBgStrong,
    Color? glassBorder,
    Color? wallpaperScrim,
    Color? modalGlassBg,
    Color? modalText1,
    Color? modalText2,
    Color? quizCorrectBg,
    Color? quizCorrectText,
    Color? quizWrongBg,
    Color? quizWrongText,
    this.vipGoldBg = const Color(0xFFFFD06A),
    this.vipGoldText = const Color(0xFF1F1F1F),
    List<Color>? profileDecor,
  }) : onGlassText1 = onGlassText1 ?? text1,
       onGlassText2 = onGlassText2 ?? text2,
       onGlassAccent = onGlassAccent ?? accent,
       glassBg = glassBg ?? cardBg,
       glassBgStrong = glassBgStrong ?? cardBg,
       glassBorder = glassBorder ?? divider,
       wallpaperScrim = wallpaperScrim ?? pageBg,
       modalGlassBg = modalGlassBg ?? cardBg,
       modalText1 = modalText1 ?? text1,
       modalText2 = modalText2 ?? text2,
       quizCorrectBg = quizCorrectBg ?? const Color(0xFFD1FAE5),
       quizCorrectText = quizCorrectText ?? const Color(0xFF4CAF50),
       quizWrongBg = quizWrongBg ?? const Color(0xFFFEE2E2),
       quizWrongText = quizWrongText ?? const Color(0xFFE3303B),
       profileDecor = profileDecor ?? const [Color(0xFFF5F5F5), Color(0xFFE8E8E8)];
}

/// 主题摘要信息（供主题选择页展示）
class ThemeSummary {
  final String id;
  final String name;
  final bool isDark;
  final List<Color> previewColors;
  const ThemeSummary({required this.id, required this.name, required this.isDark, required this.previewColors});
}
