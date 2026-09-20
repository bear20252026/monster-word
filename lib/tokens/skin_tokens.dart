// lib/tokens/skin_tokens.dart
// 9 套非星巴克皮肤色板 token（batch7，2026-09-20）。
// theme_presets 引用本文件常量；theme_token_consistency_test 锁定 preset==token。
import 'package:flutter/material.dart';

/// bright 主题色 token
class BrightThemeColors {
  static const List<Color> profileDecor = [Color(0xFFF5F5F5), Color(0xFFE8E8E8)];
  static const Color pageBg = Color(0xFFF5F5F5);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBgAlt = Color(0xFFF5F5F5);
  static const Color text1 = Color(0xDE000000);
  static const Color text2 = Color(0x8A000000);
  static const Color text3 = Color(0x9E000000);
  static const Color divider = Color(0x14000000);
  static const Color accent = Color(0xFF9E4800);
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFC02424);
  static const Color teal = Color(0xFF1565C0);
  static const Color tabBarIcon = Color(0xDE000000);
  static const Color quizCorrectBg = Color(0xFFD1FAE5);
  static const Color quizCorrectText = Color(0xFF1B5E20);
  static const Color quizWrongBg = Color(0xFFFEE2E2);
  static const Color quizWrongText = Color(0xFFB71C1C);
}

/// dark 主题色 token
class DarkThemeColors {
  static const List<Color> profileDecor = [Color(0xFF212532), Color(0xFF292F44)];
  static const Color pageBg = Color(0xFF212532);
  static const Color cardBg = Color(0xFF2E344A);
  static const Color cardBgAlt = Color(0xFF292F44);
  static const Color text1 = Color(0xDEFFFFFF);
  static const Color text2 = Color(0x8AFFFFFF);
  static const Color text3 = Color(0x9EFFFFFF);
  static const Color divider = Color(0x33FFFFFF);
  static const Color accent = Color(0xFFFFAB00);
  static const Color success = Color(0xFF22A18B);
  static const Color danger = Color(0xFFFF5252);
  static const Color teal = Color(0xFF4A90E2);
  static const Color tabBarIcon = Color(0xDEFFFFFF);
  static const Color onGlassText1 = Color(0xDEFFFFFF);
  static const Color onGlassText2 = Color(0x8AFFFFFF);
  static const Color onGlassAccent = Color(0xFFFFAB00);
  static const Color quizCorrectBg = Color(0xFF1A3D2E);
  static const Color quizCorrectText = Color(0xFF4DB6AC);
  static const Color quizWrongBg = Color(0xFF3D1A2E);
  static const Color quizWrongText = Color(0xFFFF5252);
}

/// pure_black 主题色 token
class PureBlackThemeColors {
  static const List<Color> profileDecor = [Color(0xFF040404), Color(0xFF1A1B1C)];
  static const Color pageBg = Color(0xFF040404);
  static const Color cardBg = Color(0xFF1A1B1C);
  static const Color cardBgAlt = Color(0xFF141415);
  static const Color text1 = Color(0xDEFFFFFF);
  static const Color text2 = Color(0x8AFFFFFF);
  static const Color text3 = Color(0x9EFFFFFF);
  static const Color divider = Color(0x33FFFFFF);
  static const Color accent = Color(0xFF42A5F5);
  static const Color success = Color(0xFF66BB6A);
  static const Color danger = Color(0xFFFF5252);
  static const Color teal = Color(0xFF2196F3);
  static const Color tabBarIcon = Color(0xDEFFFFFF);
  static const Color onGlassText1 = Color(0xDEFFFFFF);
  static const Color onGlassText2 = Color(0x8AFFFFFF);
  static const Color onGlassAccent = Color(0xFF42A5F5);
  static const Color quizCorrectBg = Color(0xFF0D2B22);
  static const Color quizCorrectText = Color(0xFF66BB6A);
  static const Color quizWrongBg = Color(0xFF2B0D1A);
  static const Color quizWrongText = Color(0xFFFF5252);
}

/// warm_orange 主题色 token
class WarmOrangeThemeColors {
  static const List<Color> profileDecor = [Color(0xFFFFE0B2), Color(0xFFFFF3E8)];
  static const Color pageBg = Color(0xFFFAF5EF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBgAlt = Color(0xFFFFF3E8);
  static const Color text1 = Color(0xDE000000);
  static const Color text2 = Color(0xFF795548);
  static const Color text3 = Color(0x9E000000);
  static const Color divider = Color(0x1F000000);
  static const Color accent = Color(0xFFBF360C);
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFD32F2F);
  static const Color teal = Color(0xFF1565C0);
  static const Color tabBarIcon = Color(0xDE000000);
  static const Color onGlassText1 = Color(0xDE000000);
  static const Color onGlassText2 = Color(0xFF795548);
  static const Color onGlassAccent = Color(0xFFBF360C);
  static const Color glassBg = Color(0xFFFFFFFF);
  static const Color glassBgStrong = Color(0xFFFFF3E8);
  static const Color glassBorder = Color(0x1F000000);
  static const Color wallpaperScrim = Color(0xFFFAF5EF);
  static const Color modalGlassBg = Color(0xFFFFFFFF);
  static const Color modalText1 = Color(0xDE000000);
  static const Color modalText2 = Color(0xFF8D6E63);
  static const Color quizCorrectBg = Color(0xFFD1FAE5);
  static const Color quizCorrectText = Color(0xFF1B5E20);
  static const Color quizWrongBg = Color(0xFFFEE2E2);
  static const Color quizWrongText = Color(0xFF9B1515);
  static const Color vipGoldBg = Color(0xFFF59E0B);
  static const Color vipGoldText = Color(0xFF3E2723);
}

/// claude_cream 主题色 token
class ClaudeCreamColors {
  static const List<Color> profileDecor = [Color(0xFFF5F0E8), Color(0xFFEFE9DE)];
  static const Color pageBg = Color(0xFFFAF9F5);
  static const Color cardBg = Color(0xFFF5F0E8);
  static const Color cardBgAlt = Color(0xFFEFE9DE);
  static const Color text1 = Color(0xFF141413);
  static const Color text2 = Color(0xFF6C6A64);
  static const Color text3 = Color(0xFF6C6A64);
  static const Color divider = Color(0xFFE6DFD8);
  static const Color accent = Color(0xFFA05438);
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFBF2020);
  static const Color teal = Color(0xFF00695C);
  static const Color tabBarIcon = Color(0xFF141413);
  static const Color onGlassText1 = Color(0xFF141413);
  static const Color onGlassText2 = Color(0xFF6C6A64);
  static const Color onGlassAccent = Color(0xFFA05438);
  static const Color glassBg = Color(0xFFF5F0E8);
  static const Color glassBgStrong = Color(0xFFEFE9DE);
  static const Color glassBorder = Color(0xFFE6DFD8);
  static const Color wallpaperScrim = Color(0xFFFAF9F5);
  static const Color modalGlassBg = Color(0xFFFFFFFF);
  static const Color modalText1 = Color(0xFF141413);
  static const Color modalText2 = Color(0xFF6C6A64);
  static const Color quizCorrectBg = Color(0xFFD1FAE5);
  static const Color quizCorrectText = Color(0xFF1B5E20);
  static const Color quizWrongBg = Color(0xFFFEE2E2);
  static const Color quizWrongText = Color(0xFF9B1515);
  static const Color vipGoldBg = Color(0xFFE8A55A);
  static const Color vipGoldText = Color(0xFF141413);
}

/// airbnb_light 主题色 token
class AirbnbLightColors {
  static const List<Color> profileDecor = [Color(0xFFF7F7F7), Color(0xFFFFE8EC)];
  static const Color pageBg = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBgAlt = Color(0xFFF7F7F7);
  static const Color text1 = Color(0xFF222222);
  static const Color text2 = Color(0xFF6A6A6A);
  static const Color text3 = Color(0xFF6A6A6A);
  static const Color divider = Color(0xFFDDDDDD);
  static const Color accent = Color(0xFFE00B41);
  static const Color success = Color(0xFF067D06);
  static const Color danger = Color(0xFFC13515);
  static const Color teal = Color(0xFF2563EB);
  static const Color tabBarIcon = Color(0xFF222222);
  static const Color onGlassText1 = Color(0xFF222222);
  static const Color onGlassText2 = Color(0xFF6A6A6A);
  static const Color onGlassAccent = Color(0xFFE00B41);
  static const Color glassBg = Color(0xFFFFFFFF);
  static const Color glassBgStrong = Color(0xFFF7F7F7);
  static const Color glassBorder = Color(0xFFDDDDDD);
  static const Color wallpaperScrim = Color(0xFFFFFFFF);
  static const Color modalGlassBg = Color(0xFFFFFFFF);
  static const Color modalText1 = Color(0xFF222222);
  static const Color modalText2 = Color(0xFF6A6A6A);
  static const Color quizCorrectBg = Color(0xFFD1FAE5);
  static const Color quizCorrectText = Color(0xFF1B5E20);
  static const Color quizWrongBg = Color(0xFFFEE2E2);
  static const Color quizWrongText = Color(0xFF9B1515);
  static const Color vipGoldBg = Color(0xFFFFD06A);
  static const Color vipGoldText = Color(0xFF222222);
}

/// nike_mono 主题色 token
class NikeMonoColors {
  static const List<Color> profileDecor = [Color(0xFFF5F5F5), Color(0xFFE5E5E5)];
  static const Color pageBg = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBgAlt = Color(0xFFF5F5F5);
  static const Color text1 = Color(0xFF111111);
  static const Color text2 = Color(0xFF707072);
  static const Color text3 = Color(0xFF707072);
  static const Color divider = Color(0xFFCACACB);
  static const Color accent = Color(0xFF111111);
  static const Color success = Color(0xFF007D48);
  static const Color danger = Color(0xFFD30005);
  static const Color teal = Color(0xFF1151FF);
  static const Color tabBarIcon = Color(0xFF111111);
  static const Color onGlassText1 = Color(0xFF111111);
  static const Color onGlassText2 = Color(0xFF707072);
  static const Color onGlassAccent = Color(0xFF111111);
  static const Color glassBg = Color(0xFFFFFFFF);
  static const Color glassBgStrong = Color(0xFFF5F5F5);
  static const Color glassBorder = Color(0xFFCACACB);
  static const Color wallpaperScrim = Color(0xFFFFFFFF);
  static const Color modalGlassBg = Color(0xFFFFFFFF);
  static const Color modalText1 = Color(0xFF111111);
  static const Color modalText2 = Color(0xFF707072);
  static const Color quizCorrectBg = Color(0xFFD1FAE5);
  static const Color quizCorrectText = Color(0xFF007D48);
  static const Color quizWrongBg = Color(0xFFFEE2E2);
  static const Color quizWrongText = Color(0xFFB71C1C);
  static const Color vipGoldBg = Color(0xFF111111);
  static const Color vipGoldText = Color(0xFFFFFFFF);
}

/// apple_light 主题色 token
class AppleLightColors {
  static const List<Color> profileDecor = [Color(0xFFFAFAFC), Color(0xFFF0F0F0)];
  static const Color pageBg = Color(0xFFF5F5F7);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBgAlt = Color(0xFFFAFAFC);
  static const Color text1 = Color(0xFF1D1D1F);
  static const Color text2 = Color(0xFF6E6E73);
  static const Color text3 = Color(0xFF6E6E73);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color accent = Color(0xFF0066CC);
  static const Color success = Color(0xFF1D7A33);
  static const Color danger = Color(0xFFD70015);
  static const Color teal = Color(0xFF0066CC);
  static const Color tabBarIcon = Color(0xFF1D1D1F);
  static const Color onGlassText1 = Color(0xFF1D1D1F);
  static const Color onGlassText2 = Color(0xFF6E6E73);
  static const Color onGlassAccent = Color(0xFF0066CC);
  static const Color glassBg = Color(0xFFFFFFFF);
  static const Color glassBgStrong = Color(0xFFFAFAFC);
  static const Color glassBorder = Color(0xFFE0E0E0);
  static const Color wallpaperScrim = Color(0xFFF5F5F7);
  static const Color modalGlassBg = Color(0xFFFFFFFF);
  static const Color modalText1 = Color(0xFF1D1D1F);
  static const Color modalText2 = Color(0xFF6E6E73);
  static const Color quizCorrectBg = Color(0xFFD1FAE5);
  static const Color quizCorrectText = Color(0xFF1B5E20);
  static const Color quizWrongBg = Color(0xFFFEE2E2);
  static const Color quizWrongText = Color(0xFF9B1515);
  static const Color vipGoldBg = Color(0xFFD2D2D7);
  static const Color vipGoldText = Color(0xFF1D1D1F);
}

/// clickhouse_dark 主题色 token
class ClickhouseDarkColors {
  static const List<Color> profileDecor = [Color(0xFF121212), Color(0xFF1A1A1A)];
  static const Color pageBg = Color(0xFF0A0A0A);
  static const Color cardBg = Color(0xFF1A1A1A);
  static const Color cardBgAlt = Color(0xFF242424);
  static const Color text1 = Color(0xFFFFFFFF);
  static const Color text2 = Color(0xFFCCCCCC);
  static const Color text3 = Color(0xFF9A9A9A);
  static const Color divider = Color(0xFF2A2A2A);
  static const Color accent = Color(0xFFFAFF69);
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color teal = Color(0xFF3B82F6);
  static const Color tabBarIcon = Color(0xFFFFFFFF);
  static const Color onGlassText1 = Color(0xFFFFFFFF);
  static const Color onGlassText2 = Color(0xFFCCCCCC);
  static const Color onGlassAccent = Color(0xFFFAFF69);
  static const Color glassBg = Color(0xFF1A1A1A);
  static const Color glassBgStrong = Color(0xFF242424);
  static const Color glassBorder = Color(0xFF3A3A3A);
  static const Color wallpaperScrim = Color(0xFF0A0A0A);
  static const Color modalGlassBg = Color(0xFF242424);
  static const Color modalText1 = Color(0xFFFFFFFF);
  static const Color modalText2 = Color(0xFFCCCCCC);
  static const Color quizCorrectBg = Color(0xFF14261A);
  static const Color quizCorrectText = Color(0xFF22C55E);
  static const Color quizWrongBg = Color(0xFF2B1212);
  static const Color quizWrongText = Color(0xFFEF4444);
  static const Color vipGoldBg = Color(0xFFFAFF69);
  static const Color vipGoldText = Color(0xFF0A0A0A);
}
