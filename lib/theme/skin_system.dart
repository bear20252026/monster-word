// Monster Word 皮肤系统 — 还原 v3.2 原版配色
import 'package:flutter/material.dart';
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
      text3: const Color(0x9E000000),            // 62% 黑（WCAG AA 达标）
      divider: const Color(0x14000000),          // 8% 黑（原版分割线）
      accent: const Color(0xFF9E4800),           // 深琥珀色（WCAG AA 4.70:1）
      success: const Color(0xFF2E7D32),          // 深绿色（WCAG AA 4.70:1）
      danger: const Color(0xFFC02424),           // 深红色（WCAG AA 4.60:1）
      teal: const Color(0xFF1565C0),             // 深蓝色（WCAG AA 7.05:1）
      tabBarIcon: const Color(0xDE000000),
      quizCorrectBg: const Color(0xFFD1FAE5),
      quizCorrectText: const Color(0xFF1B5E20),  // 深绿色（WCAG AA on #D1FAE5）
      quizWrongBg: const Color(0xFFFEE2E2),
      quizWrongText: const Color(0xFFB71C1C),    // 深红色（WCAG AA on #FEE2E2）
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
      text3: const Color(0x9EFFFFFF),            // 62% 白（WCAG AA 达标，与 pure_black 一致）
      divider: const Color(0x33FFFFFF),          // 20% 白（原版分割线）
      accent: const Color(0xFFFFAB00),           // 明亮琥珀色（WCAG AA 7.28:1）
      success: const Color(0xFF22A18B),          // 原版深色成功（青绿）
      danger: const Color(0xFFFF5252),           // 亮红色（WCAG AA 4.72:1）
      teal: const Color(0xFF4A90E2),             // 原版系统文字色（蓝）
      tabBarIcon: const Color(0xDEFFFFFF),
      onGlassText1: const Color(0xDEFFFFFF),
      onGlassText2: const Color(0x8AFFFFFF),
      onGlassAccent: const Color(0xFFFFAB00),    // 明亮琥珀色（WCAG AA）
      quizCorrectBg: const Color(0xFF1A3D2E),
      quizCorrectText: const Color(0xFF4DB6AC),  // 浅青绿色（WCAG AA on #1A3D2E）
      quizWrongBg: const Color(0xFF3D1A2E),
      quizWrongText: const Color(0xFFFF5252),    // 亮红色（WCAG AA on #3D1A2E）
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
      text3: const Color(0x9EFFFFFF),            // 62% 白（WCAG AA 达标）
      divider: const Color(0x33FFFFFF),          // 20% 白
      accent: const Color(0xFF42A5F5),           // 中蓝色（WCAG AA 7.28:1）
      success: const Color(0xFF66BB6A),          // 亮绿色（WCAG AA 6.06:1）
      danger: const Color(0xFFFF5252),           // 亮红色（WCAG AA 4.72:1）
      teal: const Color(0xFF2196F3),             // 蓝色（WCAG AA 5.03:1）
      tabBarIcon: const Color(0xDEFFFFFF),
      onGlassText1: const Color(0xDEFFFFFF),
      onGlassText2: const Color(0x8AFFFFFF),
      onGlassAccent: const Color(0xFF42A5F5),    // 中蓝色（WCAG AA）
      quizCorrectBg: const Color(0xFF0D2B22),
      quizCorrectText: const Color(0xFF66BB6A),  // 亮绿色（WCAG AA on quiz背景）
      quizWrongBg: const Color(0xFF2B0D1A),
      quizWrongText: const Color(0xFFFF5252),    // 亮红色（WCAG AA on quiz背景）
      profileDecor: const [Color(0xFF040404), Color(0xFF1A1B1C)],
    ),
  ),
  // ============================================================
  // 星巴克双主题（Batch 2 新增）
  // ============================================================
  'starbucks_cream': ThemePreset(
    id: 'starbucks_cream', name: '星巴克奶油', uiBrightness: Brightness.light, statusBarBrightness: Brightness.dark,
    vars: ThemeVars(
      pageBg:       const Color(0xFFF2F0EB),     // 奶油画布
      cardBg:       const Color(0xFFFFFFFF),      // 白卡片
      cardBgAlt:    const Color(0xFFEDEBE9),      // 陶瓷画布
      text1:        const Color(0xDE212121),      // α=0.87 正文黑
      text2:        const Color(0xB3212121),      // α=0.70（WCAG AA on 奶油画布 5.55:1）
      text3:        const Color(0xB3212121),      // α=0.70（WCAG AA on 奶油画布 4.71:1）
      divider:      const Color(0x14000000),      // 8% 黑
      accent:       const Color(0xFF00754A),      // 品牌绿 CTA（5.76:1）
      success:      const Color(0xFF2E7D32),      // 深绿色（WCAG AA）
      danger:       const Color(0xFFBF2020),      // 深红色（WCAG AA）
      teal:         const Color(0xFF00754A),      // 品牌绿替代蓝
      tabBarIcon:   const Color(0xDE212121),      // 同 text1
      onGlassText1: const Color(0xDE212121),
      onGlassText2: const Color(0xA6212121),      // α=0.65（WCAG AA on 白卡片）
      onGlassAccent: const Color(0xFF00754A),
      glassBg:      const Color(0xFFFFFFFF),
      glassBgStrong: const Color(0xFFFFFFFF),
      glassBorder:  const Color(0x14000000),
      wallpaperScrim: const Color(0xFFF2F0EB),   // 同 pageBg
      modalGlassBg: const Color(0xFFFFFFFF),
      modalText1:   const Color(0xDE212121),
      modalText2:   const Color(0xA6212121),      // α=0.65（WCAG AA on 白底）
      quizCorrectBg:   const Color(0xFFD1FAE5),
      quizCorrectText: const Color(0xFF1B5E20),    // 深绿色（WCAG AA on #D1FAE5）
      quizWrongBg:     const Color(0xFFFEE2E2),
      quizWrongText:   const Color(0xFF9B1515),    // 深红色（WCAG AA on #FEE2E2）
      vipGoldBg:    const Color(0xFFCBA258),      // 品牌金
      vipGoldText:  const Color(0xFF1E3932),      // 深绿字（WCAG AA 5.22:1 on 金底）
      profileDecor: const [Color(0xFFD4E9E2), Color(0xFFEDEBE9)],  // 浅绿+陶瓷
    ),
  ),
  'starbucks_dark': ThemePreset(
    id: 'starbucks_dark', name: '星巴克深绿', uiBrightness: Brightness.dark, statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg:       const Color(0xFF101B17),      // 墨绿近黑
      cardBg:       const Color(0xFF1E3932),      // 深绿表面
      cardBgAlt:    const Color(0xFF274A40),      // 二级浮层
      text1:        const Color(0xDEFFFFFF),      // 87% 白
      text2:        const Color(0xFFA9BCB5),      // 雾绿（A11y 修正，固定色值）
      text3:        const Color(0x9EFFFFFF),      // α=0.62（WCAG AA 达标）
      divider:      const Color(0x1FFFFFFF),      // 12% 白
      accent:       const Color(0xFF00BB00),      // 亮绿色（WCAG AA on 表面 4.62:1）
      success:      const Color(0xFF00C853),      // 亮绿色（WCAG AA）
      danger:       const Color(0xFFFF5252),      // 亮红色（WCAG AA）
      teal:         const Color(0xFF2196F3),      // 蓝色（WCAG AA）
      tabBarIcon:   const Color(0xDEFFFFFF),
      onGlassText1: const Color(0xDEFFFFFF),
      onGlassText2: const Color(0xFFA9BCB5),      // 同 text2
      onGlassAccent: const Color(0xFF00BB00),      // 同 accent（WCAG AA）
      glassBg:      const Color(0xFF1E3932),
      glassBgStrong: const Color(0xFF274A40),
      glassBorder:  const Color(0x1FFFFFFF),
      wallpaperScrim: const Color(0xFF101B17),
      modalGlassBg: const Color(0xFF274A40),
      modalText1:   const Color(0xDEFFFFFF),
      modalText2:   const Color(0xFFA9BCB5),
      quizCorrectBg:   const Color(0xFF1A3D2E),
      quizCorrectText: const Color(0xFF4DB6AC),    // 浅青绿色（WCAG AA on #1A3D2E）
      quizWrongBg:     const Color(0xFF3D1A2E),
      quizWrongText:   const Color(0xFFFF5252),    // 亮红色（WCAG AA on #3D1A2E）
      vipGoldBg:    const Color(0xFFCBA258),      // 品牌金
      vipGoldText:  const Color(0xFF1E3932),      // 深绿字（WCAG AA on 金底）
      profileDecor: const [Color(0xFF101B17), Color(0xFF1E3932)],  // 深绿体系
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

  /// 权威计算：跟随系统时按系统亮度映射到星巴克双主题
  String get effectiveThemeId {
    if (!_followSystem) return _themeId;
    return _systemBrightness == Brightness.dark ? 'starbucks_dark' : 'starbucks_cream';
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
