// Monster Word 皮肤系统 — 还原 v3.2 原版配色
import 'package:flutter/material.dart';
import '../tokens/design_tokens.dart';
import '../data/app_preferences.dart';

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
        quizCorrectText = quizCorrectText ?? const Color(0xFF4CAF50),
        quizWrongBg = quizWrongBg ?? const Color(0xFFFEE2E2),
        quizWrongText = quizWrongText ?? const Color(0xFFE3303B),
        profileDecor = profileDecor ?? const [Color(0xFFF5F5F5), Color(0xFFE8E8E8)];
}

class ThemePreset {
  final String id;
  final String name;
  /// UI 亮度：驱动 ThemeData/ColorScheme（组件按亮或暗渲染）
  final Brightness uiBrightness;
  /// 状态栏图标明暗：仅供未来 SystemChrome/AnnotatedRegion 使用（本批不接线）
  final Brightness statusBarBrightness;
  final ThemeVars vars;
  const ThemePreset({required this.id, required this.name, required this.uiBrightness, required this.statusBarBrightness, required this.vars});
}

/// 三档主题：还原 v3.2 原版配色
/// - 明亮（AppLightTheme）：浅灰背景 + 橙色强调
/// - 深邃（AppDarkTheme）：深蓝灰背景 + 金色强调
/// - 极夜（AppBlackTheme）：纯黑背景 + 蓝色强调
final themes = <String, ThemePreset>{
  'bright': ThemePreset(
    id: 'bright', name: '明亮', uiBrightness: Brightness.light, statusBarBrightness: Brightness.dark,
    vars: ThemeVars(
      pageBg: const Color(0xFFF5F5F5),          // 原版亮色背景
      cardBg: const Color(0xFFFFFFFF),           // 原版白色卡片
      cardBgAlt: const Color(0xFFF5F5F5),
      text1: const Color(0xDE000000),            // 87% 黑（原版主文字）
      text2: const Color(0x8A000000),            // 54% 黑（原版次文字）
      text3: const Color(0x61000000),            // 38% 黑（原版三级文字）
      divider: const Color(0x14000000),          // 8% 黑（原版分割线）
      accent: const Color(0xFFE8913A),           // 原版亮色强调（橙色）
      success: const Color(0xFF4CAF50),          // 原版亮色成功（绿色）
      danger: const Color(0xFFE3303B),           // 原版亮色错误（红）
      teal: const Color(0xFF4A90E2),             // 原版系统文字色（蓝）
      tabBarIcon: const Color(0xDE000000),
      quizCorrectBg: const Color(0xFFD1FAE5),
      quizCorrectText: const Color(0xFF4CAF50),
      quizWrongBg: const Color(0xFFFEE2E2),
      quizWrongText: const Color(0xFFE3303B),
      profileDecor: const [Color(0xFFF5F5F5), Color(0xFFE8E8E8)],
    ),
  ),
  'dark': ThemePreset(
    id: 'dark', name: '深邃', uiBrightness: Brightness.dark, statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg: const Color(0xFF212532),           // 原版深色背景（深蓝灰）
      cardBg: const Color(0xFF2E344A),           // 原版深色卡片（蓝灰）
      cardBgAlt: const Color(0xFF292F44),        // 原版前景色
      text1: const Color(0xDEFFFFFF),            // 87% 白（原版主文字）
      text2: const Color(0x8AFFFFFF),            // 54% 白（原版次文字）
      text3: const Color(0x61FFFFFF),            // 38% 白（原版三级文字）
      divider: const Color(0x33FFFFFF),          // 20% 白（原版分割线）
      accent: const Color(0xFFF4A100),           // 原版深色高亮（金色）
      success: const Color(0xFF22A18B),          // 原版深色成功（青绿）
      danger: const Color(0xFFC64354),           // 原版深色错误（玫红）
      teal: const Color(0xFF4A90E2),             // 原版系统文字色（蓝）
      tabBarIcon: const Color(0xDEFFFFFF),
      onGlassText1: const Color(0xDEFFFFFF),
      onGlassText2: const Color(0x8AFFFFFF),
      onGlassAccent: const Color(0xFFF4A100),
      quizCorrectBg: const Color(0xFF1A3D2E),
      quizCorrectText: const Color(0xFF22A18B),
      quizWrongBg: const Color(0xFF3D1A2E),
      quizWrongText: const Color(0xFFC64354),
      profileDecor: const [Color(0xFF212532), Color(0xFF292F44)],
    ),
  ),
  'pure_black': ThemePreset(
    id: 'pure_black', name: '极夜', uiBrightness: Brightness.dark, statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg: const Color(0xFF040404),           // 原版极夜背景
      cardBg: const Color(0xFF1A1B1C),           // 原版极夜卡片
      cardBgAlt: const Color(0xFF141415),
      text1: const Color(0xDEFFFFFF),            // 87% 白
      text2: const Color(0x8AFFFFFF),            // 54% 白
      text3: const Color(0x61FFFFFF),            // 38% 白
      divider: const Color(0x33FFFFFF),          // 20% 白
      accent: const Color(0xFF005F87),           // 原版极夜强调（蓝色）
      success: const Color(0xFF22A18B),
      danger: const Color(0xFFC64354),
      teal: const Color(0xFF005F87),
      tabBarIcon: const Color(0xDEFFFFFF),
      onGlassText1: const Color(0xDEFFFFFF),
      onGlassText2: const Color(0x8AFFFFFF),
      onGlassAccent: const Color(0xFF005F87),
      quizCorrectBg: const Color(0xFF0D2B22),
      quizCorrectText: const Color(0xFF22A18B),
      quizWrongBg: const Color(0xFF2B0D1A),
      quizWrongText: const Color(0xFFC64354),
      profileDecor: const [Color(0xFF040404), Color(0xFF1A1B1C)],
    ),
  ),
};

class SkinSystem extends ChangeNotifier {
  String _themeId = 'bright';
  bool _followSystem = false;

  String get themeId => _themeId;
  bool get followSystem => _followSystem;
  ThemePreset get currentTheme => themes[_themeId]!;
  ThemeVars get colors => currentTheme.vars;

  /// 当前系统亮度（监听刷新）
  Brightness _systemBrightness = WidgetsBinding
      .instance.platformDispatcher.platformBrightness;

  SkinSystem() {
    try {
      final saved = AppPreferences().getSkinThemeId();
      _themeId = themes.containsKey(saved) ? saved : 'bright';   // 非法值兜底
      _followSystem = AppPreferences().isSkinFollowSystem();
    } catch (e) {
      // 测试环境或未初始化时使用默认值
      _themeId = 'bright';
      _followSystem = false;
    }
  }

  void setFollowSystem(bool v) {
    if (_followSystem == v) return;
    _followSystem = v;
    notifyListeners();
    AppPreferences().setSkinFollowSystem(v);            // fire-and-forget
  }

  void setTheme(String id) {
    if (!themes.containsKey(id)) return;
    _themeId = id;
    if (_followSystem) setFollowSystem(false);          // 手动选择即退出跟随
    notifyListeners();
    AppPreferences().setSkinThemeId(_themeId);          // ← 持久化落点
  }

  /// 权威计算：跟随系统时按系统亮度映射到 dark/pure_black 二选一
  String get effectiveThemeId {
    if (!_followSystem) return _themeId;
    return _systemBrightness == Brightness.dark ? 'pure_black' : 'bright';
  }

  Brightness get effectiveUiBrightness =>
      themes[effectiveThemeId]!.uiBrightness;           // §1.3 的消费源

  /// 系统亮度变化回调（由 WordApp State 触发）
  void updateSystemBrightness(Brightness b) {
    if (_systemBrightness == b) return;
    _systemBrightness = b;
    if (_followSystem) notifyListeners();
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
  bool updateShouldNotify(SkinProvider old) =>
      skin.effectiveThemeId != old.skin.effectiveThemeId ||
      skin.followSystem != old.skin.followSystem;
}

extension SkinExt on BuildContext {
  SkinSystem get skin => SkinProvider.of(this);
}
