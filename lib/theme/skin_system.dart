// Monster Word 皮肤系统（运行时状态）。
//
// 数据层拆分：
//   theme_vars.dart      — ThemeVars 语义色 / ThemeSummary
//   theme_presets.dart   — 11 套底层色板 themes
//   style_catalog.dart   — kMwStyles 6 个用户可见精选风格
//   style_migration.dart — 旧主题偏好迁移
// 本文件保留运行时：SkinSystem 状态机 + SkinProvider 注入 + context 扩展。

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';

import 'package:word_app/tokens/design_language.dart';

export 'package:word_app/tokens/design_language.dart';

import 'package:word_app/theme/style_catalog.dart';
import 'package:word_app/theme/theme_presets.dart';
import 'package:word_app/theme/theme_vars.dart';

export 'package:word_app/theme/style_catalog.dart';
export 'package:word_app/theme/theme_presets.dart';
export 'package:word_app/theme/theme_vars.dart';

class SkinSystem extends ChangeNotifier {
  /// 旧主题 id → 精选风格（老用户升级时的偏好迁移，幂等）
  static const Map<String, String> legacyThemeMigration = {
    'bright': 'starbucks_cream',
    'warm_orange': 'starbucks_cream',
    'dark': 'starbucks_dark',
    'pure_black': 'starbucks_dark',
    'clickhouse_dark': 'starbucks_dark',
  };

  String _themeId = 'starbucks_cream';
  bool _followSystem = false;

  /// 用户选择的字体覆盖（null = 默认 Inter）。持久化走独立的 SharedPreferences 键，
  /// 与主题偏好解耦。
  String? _fontFamily;
  static const String _kFontPrefKey = 'app.font_family';

  /// 用户选择的 B 档设计语言（与颜色主题正交；缺省星巴克）。
  String _designLanguageId = 'starbucks';
  static const String _kDesignPrefKey = 'app.design_language';

  String get themeId => _themeId;
  bool get followSystem => _followSystem;
  ThemePreset get currentTheme => themes[_themeId]!;
  ThemeVars get colors => currentTheme.vars;

  /// 当前 B 档设计语言（皮肤(颜色)之外整套视觉/形态令牌）。
  /// 切换设计语言 = 整套半径/间距/阴影/字体比例随之变化。
  DesignLanguage get design => DesignLanguages.byId(_designLanguageId);

  /// 用户当前选中的 B 档设计语言 id。
  String get designLanguageId => _designLanguageId;

  /// 当前生效的精选风格 id（主题+语言精确匹配 → 仅主题匹配 → 默认）。
  String get currentStyleId {
    final t = effectiveThemeId;
    for (final s in kMwStyles) {
      if (s.themeId == t && s.languageId == _designLanguageId) return s.id;
    }
    for (final s in kMwStyles) {
      if (s.themeId == t) return s.id;
    }
    return kMwStyles.first.id;
  }

  /// 一键切换精选风格：同时绑定 A 档颜色主题与 B 档设计语言，原子生效。
  void setStyle(String id) {
    if (currentStyleId == id) return;
    final style = kMwStyles.where((s) => s.id == id).firstOrNull;
    if (style == null) return;
    setDesignLanguage(style.languageId);
    setTheme(style.themeId);
  }

  /// 当前风格的展示名（设置行值用）。
  String get currentStyleName {
    final id = currentStyleId;
    return kMwStyles.where((s) => s.id == id).firstOrNull?.name ?? '';
  }

  /// 当前系统亮度（监听刷新）
  Brightness _systemBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;

  SkinSystem() {
    try {
      final saved = AppPreferences().getSkinThemeId();
      // 旧偏好（明亮/暖阳橙/深邃/极夜/ClickHouse）迁移到最近的精选风格主题
      _themeId = themes.containsKey(saved) ? saved : 'starbucks_cream';
      _themeId = legacyThemeMigration[_themeId] ?? _themeId;
      _followSystem = AppPreferences().isSkinFollowSystem();
    } catch (e) {
      // 测试环境或未初始化时使用默认值
      _themeId = 'starbucks_cream';
      _followSystem = false;
    }
    // 异步恢复字体偏好（构造器是同步的，加载后通知刷新）
    _loadFontPreference();
    _loadDesignPreference();
  }

  Future<void> _loadFontPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kFontPrefKey);
      if (saved != _fontFamily && mounted) {
        _fontFamily = saved;
        notifyListeners();
      }
    } catch (_) {
      // 测试环境无插件时静默忽略
    }
  }

  /// 当前字体覆盖（null = 使用默认 Inter）
  String? get fontFamilyOverride => _fontFamily;

  /// 供 MaterialApp.theme 使用的实际字体族：'system' 视为平台默认（返回 null）
  String? get effectiveFontFamily => (_fontFamily == null || _fontFamily == 'system') ? null : _fontFamily;

  /// 设置字体覆盖；传 null 恢复默认。可选值见 appearance_page 的字体选择对话框。
  void setFontFamily(String? family) {
    if (_fontFamily == family) return;
    _fontFamily = family;
    notifyListeners();
    // fire-and-forget 持久化
    SharedPreferences.getInstance()
        .then((p) {
          if (family == null) {
            return p.remove(_kFontPrefKey);
          } else {
            return p.setString(_kFontPrefKey, family);
          }
        })
        .catchError((e) => false);
  }

  /// 切换 B 档设计语言（整套半径/间距/阴影/字体比例）。持久化并通知重建。
  void setDesignLanguage(String id) {
    if (!DesignLanguages.all.containsKey(id) || _designLanguageId == id) return;
    _designLanguageId = id;
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setString(_kDesignPrefKey, id)).catchError((e) => false);
  }

  /// 品牌风格 → 默认颜色主题映射（整站换肤 A/B 联动用）。
  static const Map<String, String> brandThemeMap = {
    'starbucks': 'starbucks_cream',
    'airbnb': 'airbnb_light',
    'nike': 'nike_mono',
    'apple': 'apple_light',
    'clickhouse': 'clickhouse_dark',
    'claude': 'claude_cream',
  };

  /// 一键品牌换肤：同时切换 A 档颜色主题 + B 档设计语言。
  /// 颜色主题取 [brandThemeMap] 的品牌默认色；无映射则只切 B 档。
  void setBrandStyle(String designId) {
    setDesignLanguage(designId);
    final themeId = brandThemeMap[designId];
    if (themeId != null && themes.containsKey(themeId) && effectiveThemeId != themeId) {
      _themeId = themeId;
      if (_followSystem) setFollowSystem(false); // 手动品牌选择即退出跟随
      notifyListeners();
      AppPreferences().setSkinThemeId(_themeId);
    }
  }

  Future<void> _loadDesignPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kDesignPrefKey);
      if (saved != null && DesignLanguages.all.containsKey(saved) && saved != _designLanguageId) {
        _designLanguageId = saved;
        notifyListeners();
      }
    } catch (_) {
      // 测试环境无插件时静默忽略
    }
  }

  /// ChangeNotifier 挂载状态（测试环境中可能未绑定）
  bool get mounted => true;

  void setFollowSystem(bool v) {
    if (_followSystem == v) return;
    _followSystem = v;
    notifyListeners();
    AppPreferences().setSkinFollowSystem(v); // fire-and-forget
  }

  void setTheme(String id) {
    if (!themes.containsKey(id)) return;
    _themeId = id;
    if (_followSystem) setFollowSystem(false); // 手动选择即退出跟随
    notifyListeners();
    AppPreferences().setSkinThemeId(_themeId); // ← 持久化落点
  }

  /// 权威计算：跟随系统时按系统亮度映射到星巴克双主题
  String get effectiveThemeId {
    if (!_followSystem) return _themeId;
    return _systemBrightness == Brightness.dark ? 'starbucks_dark' : 'starbucks_cream';
  }

  Brightness get effectiveUiBrightness => themes[effectiveThemeId]!.uiBrightness; // §1.3 的消费源

  /// 系统亮度变化回调（由 WordApp State 触发）
  void updateSystemBrightness(Brightness b) {
    if (_systemBrightness == b) return;
    _systemBrightness = b;
    if (_followSystem) notifyListeners();
  }
}

/// SkinProvider — 将 SkinSystem（ChangeNotifier）注入 widget 树
///
/// 核心修复：继承 `InheritedNotifier<SkinSystem>` 而非 `InheritedWidget`。
/// InheritedNotifier 会自动监听 notifier 的 notifyListeners() 调用，
/// 并在通知时重建所有依赖者。这解决了主题切换时 UI 不更新的问题。
class SkinProvider extends InheritedNotifier<SkinSystem> {
  const SkinProvider({super.key, required SkinSystem skin, required super.child}) : super(notifier: skin);

  static SkinSystem of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<SkinProvider>();
    return provider?.notifier ?? SkinSystem();
  }
}

extension SkinExt on BuildContext {
  SkinSystem get skin => SkinProvider.of(this);

  /// 当前 B 档设计语言（皮肤(颜色)之外的整套视觉/形态令牌）。
  ///
  /// 读取它即隐式订阅 SkinProvider，皮肤/设计语言变化时该 widget 重建 —— 这正是
  /// 「B 档整体切换」的运行时生效点。未包裹 SkinProvider 的测试环境回退默认设计语言。
  DesignLanguage get design => SkinProvider.of(this).design;
}
