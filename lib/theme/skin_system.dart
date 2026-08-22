// 由账号4生成
// Apple Design Language 2026 皮肤系统
import 'package:flutter/material.dart';

/// 苹果风格主题变量
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

  // 兼容字段（映射到苹果色值）
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
    this.vipGoldBg = const Color(0xFFF5E6C8),
    this.vipGoldText = const Color(0xFFC9A227),
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
        quizCorrectBg = quizCorrectBg ?? const Color(0xFFC1EFEA),
        quizCorrectText = quizCorrectText ?? const Color(0xFF2FA89F),
        quizWrongBg = quizWrongBg ?? const Color(0xFFFDDCDC),
        quizWrongText = quizWrongText ?? const Color(0xFFE8463A),
        profileDecor = profileDecor ?? const [Color(0xFFF5F5F7), Color(0xFFE8E8ED)];
}

/// 苹果风格主题预设
class ThemePreset {
  final String id;
  final String name;
  final Brightness statusBarBrightness;
  final ThemeVars vars;

  const ThemePreset({
    required this.id,
    required this.name,
    required this.statusBarBrightness,
    required this.vars,
  });
}

/// 苹果标准三档主题
final themes = <String, ThemePreset>{
  'bright': ThemePreset(
    id: 'bright',
    name: '明亮',
    statusBarBrightness: Brightness.dark,
    vars: ThemeVars(
      pageBg: const Color(0xFFF5F5F7),
      cardBg: const Color(0xFFFFFFFF),
      cardBgAlt: const Color(0xFFFAFAFC),
      text1: const Color(0xFF1D1D1F),
      text2: const Color(0xFF333333),
      text3: const Color(0xFF7A7A7A),
      divider: const Color(0xFFE0E0E0),
      accent: const Color(0xFF0066CC),
      success: const Color(0xFF30D158),
      danger: const Color(0xFFFF453A),
      teal: const Color(0xFF0066CC),
      tabBarIcon: const Color(0xFF1D1D1F),
    ),
  ),
  'dark': ThemePreset(
    id: 'dark',
    name: '深邃',
    statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg: const Color(0xFF000000),
      cardBg: const Color(0xFF1C1C1E),
      cardBgAlt: const Color(0xFF2C2C2E),
      text1: const Color(0xFFFFFFFF),
      text2: const Color(0xFFEBEBF5),
      text3: const Color(0xFF8E8E93),
      divider: const Color(0xFF38383A),
      accent: const Color(0xFF0A84FF),
      success: const Color(0xFF30D158),
      danger: const Color(0xFFFF453A),
      teal: const Color(0xFF0A84FF),
      tabBarIcon: const Color(0xFFFFFFFF),
    ),
  ),
  'pure_black': ThemePreset(
    id: 'pure_black',
    name: '极夜',
    statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg: const Color(0xFF000000),
      cardBg: const Color(0xFF1C1C1E),
      cardBgAlt: const Color(0xFF1C1C1E),
      text1: const Color(0xFFFFFFFF),
      text2: const Color(0xFFEBEBF5),
      text3: const Color(0xFF8E8E93),
      divider: const Color(0xFF2C2C2E),
      accent: const Color(0xFF0A84FF),
      success: const Color(0xFF30D158),
      danger: const Color(0xFFFF453A),
      teal: const Color(0xFF0A84FF),
      tabBarIcon: const Color(0xFFFFFFFF),
    ),
  ),
};

/// 皮肤系统 Provider
class SkinSystem extends ChangeNotifier {
  String _themeId = 'bright';

  String get themeId => _themeId;
  ThemePreset get currentTheme => themes[_themeId]!;
  ThemeVars get colors => currentTheme.vars;

  void setTheme(String id) {
    if (themes.containsKey(id)) {
      _themeId = id;
      notifyListeners();
    }
  }
}

/// 皮肤系统 InheritedWidget
class SkinProvider extends InheritedWidget {
  final SkinSystem skin;
  const SkinProvider({super.key, required this.skin, required super.child});

  static SkinSystem of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<SkinProvider>();
    return provider?.skin ?? SkinSystem();
  }

  @override
  bool updateShouldNotify(SkinProvider oldWidget) => skin.themeId != oldWidget.skin.themeId;
}

/// BuildContext 快捷访问
extension SkinExt on BuildContext {
  SkinSystem get skin => SkinProvider.of(this);
}
