// 由账号4生成
// Monster Word 皮肤系统 — Mistral AI 暖色风格
import 'package:flutter/material.dart';
import '../tokens/design_tokens.dart';

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
  })  : onGlassText1 = onGlassText1 ?? text1,
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
        quizCorrectText = quizCorrectText ?? const Color(0xFF16A34A),
        quizWrongBg = quizWrongBg ?? const Color(0xFFFEE2E2),
        quizWrongText = quizWrongText ?? const Color(0xFFDC2626),
        profileDecor = profileDecor ?? const [Color(0xFFFFF8E0), Color(0xFFFFFAEB)];
}

class ThemePreset {
  final String id;
  final String name;
  final Brightness statusBarBrightness;
  final ThemeVars vars;
  const ThemePreset({required this.id, required this.name, required this.statusBarBrightness, required this.vars});
}

/// 三档主题：明亮（奶油暖调）、深邃、极夜
final themes = <String, ThemePreset>{
  'bright': ThemePreset(
    id: 'bright', name: '明亮', statusBarBrightness: Brightness.dark,
    vars: ThemeVars(
      pageBg: MistralColors.cream,
      cardBg: MistralColors.canvas,
      cardBgAlt: MistralColors.creamLight,
      text1: MistralColors.ink,
      text2: MistralColors.slate,
      text3: MistralColors.stone,
      divider: MistralColors.hairline,
      accent: MistralColors.primary,
      success: MistralColors.success,
      danger: MistralColors.danger,
      teal: MistralColors.primary,
      tabBarIcon: MistralColors.ink,
    ),
  ),
  'dark': ThemePreset(
    id: 'dark', name: '深邃', statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg: MistralColors.charcoal,
      cardBg: const Color(0xFF3A3A3A),
      cardBgAlt: const Color(0xFF333333),
      text1: MistralColors.canvas,
      text2: MistralColors.muted,
      text3: MistralColors.stone,
      divider: const Color(0xFF4A4A4A),
      accent: MistralColors.sunshine500,
      success: const Color(0xFF4ADE80),
      danger: const Color(0xFFF87171),
      teal: MistralColors.sunshine500,
      tabBarIcon: MistralColors.canvas,
    ),
  ),
  'pure_black': ThemePreset(
    id: 'pure_black', name: '极夜', statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg: MistralColors.surfaceCode,
      cardBg: const Color(0xFF2C2C2E),
      cardBgAlt: const Color(0xFF242426),
      text1: MistralColors.canvas,
      text2: MistralColors.muted,
      text3: MistralColors.stone,
      divider: const Color(0xFF3A3A3C),
      accent: MistralColors.sunshine700,
      success: const Color(0xFF4ADE80),
      danger: const Color(0xFFF87171),
      teal: MistralColors.sunshine700,
      tabBarIcon: MistralColors.canvas,
    ),
  ),
};

class SkinSystem extends ChangeNotifier {
  String _themeId = 'bright';
  String get themeId => _themeId;
  ThemePreset get currentTheme => themes[_themeId]!;
  ThemeVars get colors => currentTheme.vars;

  void setTheme(String id) {
    if (themes.containsKey(id)) { _themeId = id; notifyListeners(); }
  }
}

class SkinProvider extends InheritedWidget {
  final SkinSystem skin;
  const SkinProvider({super.key, required this.skin, required super.child});
  static SkinSystem of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<SkinProvider>();
    return provider?.skin ?? SkinSystem();
  }
  @override
  bool updateShouldNotify(SkinProvider old) => skin.themeId != old.skin.themeId;
}

extension SkinExt on BuildContext {
  SkinSystem get skin => SkinProvider.of(this);
}
