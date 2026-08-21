// 由账号4生成
// L5 皮肤系统：三主题（明亮/深邃/极夜）+ 壁纸槽位 + 玻璃色值
// 翻译自 Figma skinSystem.js，壁纸=照片可替换，玻璃分黑白两版

import 'package:flutter/material.dart';

/// 主题变量（原版 THEMES.*.vars）
class ThemeVars {
  // 页面区（iOS 分组色阶）
  final Color pageBg;
  final Color cardBg;
  final Color cardBgAlt;
  final Color text1;
  final Color text2;
  final Color text3;
  final Color divider;
  final Color toggleOff;
  final Color segmentTrack;
  final Color listPressed;

  // 强调
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color danger;
  final Color teal;
  final Color vipGoldBg;
  final Color vipGoldText;

  // 答题反馈
  final Color quizCorrectBg;
  final Color quizCorrectText;
  final Color quizWrongBg;
  final Color quizWrongText;

  // 壁纸区：玻璃
  final Color wallpaperScrim;
  final String glassTint; // 'light' 或 'dark'
  final Color glassBg;
  final Color glassBgStrong;
  final Color glassBorder;
  final Color onGlassText1;
  final Color onGlassText2;
  final Color onGlassAccent;

  // 模态玻璃
  final Color modalGlassBg;
  final Color modalText1;
  final Color modalText2;

  // 专属背景
  final List<Color> profileDecor;
  final List<Color> studyGradient;
  final Color tabBarIcon;

  const ThemeVars({
    required this.pageBg,
    required this.cardBg,
    required this.cardBgAlt,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.divider,
    required this.toggleOff,
    required this.segmentTrack,
    required this.listPressed,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.danger,
    required this.teal,
    required this.vipGoldBg,
    required this.vipGoldText,
    required this.quizCorrectBg,
    required this.quizCorrectText,
    required this.quizWrongBg,
    required this.quizWrongText,
    required this.wallpaperScrim,
    required this.glassTint,
    required this.glassBg,
    required this.glassBgStrong,
    required this.glassBorder,
    required this.onGlassText1,
    required this.onGlassText2,
    required this.onGlassAccent,
    required this.modalGlassBg,
    required this.modalText1,
    required this.modalText2,
    required this.profileDecor,
    required this.studyGradient,
    required this.tabBarIcon,
  });
}

/// 主题预设（原版 THEMES）
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

/// 三档主题定义（原版 THEMES 常量）
const themes = <String, ThemePreset>{
  'bright': ThemePreset(
    id: 'bright',
    name: '明亮',
    statusBarBrightness: Brightness.dark,
    vars: ThemeVars(
      pageBg: Color(0xFFF5F5F7),
      cardBg: Color(0xFFFFFFFF),
      cardBgAlt: Color(0xFFF2F2F7),
      text1: Color(0xFF1A1A1A),
      text2: Color(0xFF666666),
      text3: Color(0xFF999999),
      divider: Color(0xFFE5E5EA),
      toggleOff: Color(0xFFE5E5EA),
      segmentTrack: Color(0x0D000000),
      listPressed: Color(0xFFF2F2F7),
      accent: Color(0xFFFF9500),
      accentSoft: Color(0xFFFFF1E9),
      success: Color(0xFF4CAF50),
      danger: Color(0xFFE8463A),
      teal: Color(0xFF3EB8B0),
      vipGoldBg: Color(0xFFF5E6C8),
      vipGoldText: Color(0xFFC9A227),
      quizCorrectBg: Color(0xFFC1EFEA),
      quizCorrectText: Color(0xFF2FA89F),
      quizWrongBg: Color(0xFFFDDCDC),
      quizWrongText: Color(0xFFE8463A),
      wallpaperScrim: Color(0x14FFFCF5),
      glassTint: 'light',
      glassBg: Color(0x6BFFFFFF),
      glassBgStrong: Color(0x94FFFFFF),
      glassBorder: Color(0xA6FFFFFF),
      onGlassText1: Color(0xFF1A1A1A),
      onGlassText2: Color(0xFF666666),
      onGlassAccent: Color(0xFFFF8A00),
      modalGlassBg: Color(0xF0FFFFFF),
      modalText1: Color(0xFF1A1A1A),
      modalText2: Color(0xFF666666),
      profileDecor: [Color(0xFFFDF6E3), Color(0xFFF5EEDD)],
      studyGradient: [Color(0xFFE8F4F8), Color(0xFFF0F0F0)],
      tabBarIcon: Color(0xFF1A1A1A),
    ),
  ),
  'dark': ThemePreset(
    id: 'dark',
    name: '深邃',
    statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg: Color(0xFF1C1F2E),
      cardBg: Color(0xFF2A2E42),
      cardBgAlt: Color(0xFF232738),
      text1: Color(0xFFFFFFFF),
      text2: Color(0xFFB0B4C4),
      text3: Color(0xFF8E8E93),
      divider: Color(0xFF3A3E52),
      toggleOff: Color(0xFF3A3E52),
      segmentTrack: Color(0x14FFFFFF),
      listPressed: Color(0xFF333850),
      accent: Color(0xFFFF9F0A),
      accentSoft: Color(0x29FF9F0A),
      success: Color(0xFF30D158),
      danger: Color(0xFFFF6B61),
      teal: Color(0xFF4FC6BE),
      vipGoldBg: Color(0x33C9A227),
      vipGoldText: Color(0xFFE0B94F),
      quizCorrectBg: Color(0x473EB8B0),
      quizCorrectText: Color(0xFF5ED4CB),
      quizWrongBg: Color(0x47E8463A),
      quizWrongText: Color(0xFFFF8A80),
      wallpaperScrim: Color(0x8C000000),
      glassTint: 'dark',
      glassBg: Color(0x21FFFFFF),
      glassBgStrong: Color(0x2EFFFFFF),
      glassBorder: Color(0x33FFFFFF),
      onGlassText1: Color(0xFFFFFFFF),
      onGlassText2: Color(0xFFD4D4D4),
      onGlassAccent: Color(0xFFFF9F0A),
      modalGlassBg: Color(0xF2464854),
      modalText1: Color(0xFFFFFFFF),
      modalText2: Color(0xFFD4D4D4),
      profileDecor: [Color(0xFF232738), Color(0xFF1C1F2E)],
      studyGradient: [Color(0xFF23283A), Color(0xFF1C1F2E)],
      tabBarIcon: Color(0xFFF2F2F7),
    ),
  ),
  'pure_black': ThemePreset(
    id: 'pure_black',
    name: '极夜',
    statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg: Color(0xFF000000),
      cardBg: Color(0xFF1C1C1E),
      cardBgAlt: Color(0xFF141416),
      text1: Color(0xFFFFFFFF),
      text2: Color(0xFFAEAEB2),
      text3: Color(0xFF8E8E93),
      divider: Color(0xFF2C2C2E),
      toggleOff: Color(0xFF2C2C2E),
      segmentTrack: Color(0x1AFFFFFF),
      listPressed: Color(0xFF1C1C1E),
      accent: Color(0xFFFF9F0A),
      accentSoft: Color(0x29FF9F0A),
      success: Color(0xFF30D158),
      danger: Color(0xFFFF6B61),
      teal: Color(0xFF4FC6BE),
      vipGoldBg: Color(0x33C9A227),
      vipGoldText: Color(0xFFE0B94F),
      quizCorrectBg: Color(0x4D3EB8B0),
      quizCorrectText: Color(0xFF5ED4CB),
      quizWrongBg: Color(0x4DE8463A),
      quizWrongText: Color(0xFFFF8A80),
      wallpaperScrim: Color(0xB8000000),
      glassTint: 'dark',
      glassBg: Color(0x1AFFFFFF),
      glassBgStrong: Color(0x26FFFFFF),
      glassBorder: Color(0x2EFFFFFF),
      onGlassText1: Color(0xFFFFFFFF),
      onGlassText2: Color(0xFFD4D4D4),
      onGlassAccent: Color(0xFFFF9F0A),
      modalGlassBg: Color(0xF52C2C2E),
      modalText1: Color(0xFFFFFFFF),
      modalText2: Color(0xFFD4D4D4),
      profileDecor: [Color(0xFF141416), Color(0xFF000000)],
      studyGradient: [Color(0xFF101012), Color(0xFF000000)],
      tabBarIcon: Color(0xFFF2F2F7),
    ),
  ),
};

/// 壁纸预设（原版 WALLPAPER_SLOTS.home_wallpaper.presets）
class WallpaperPreset {
  final String id;
  final String name;
  final String word;
  final String? uri; // null = 用兜底渐变
  final String tone; // warm / cool / dark

  const WallpaperPreset({
    required this.id,
    required this.name,
    required this.word,
    this.uri,
    required this.tone,
  });
}

const wallpaperPresets = <WallpaperPreset>[
  WallpaperPreset(id: 'beach', name: '海岸日落', word: 'Choppy', tone: 'warm'),
  WallpaperPreset(id: 'mist', name: '云雾山景', word: 'Mist', tone: 'cool'),
  WallpaperPreset(id: 'house', name: '剧集剧照', word: 'instinct', tone: 'dark'),
  WallpaperPreset(id: 'osmanthus', name: '桂花浅黄', word: 'Fragrance', tone: 'warm'),
];

/// 壁纸兜底渐变（无照片时按「色调 × 主题」合成）
const wallpaperFallback = <String, Map<String, List<Color>>>{
  'warm': {
    'bright': [Color(0xFFF5E6C8), Color(0xFFE8D5A3)],
    'dark': [Color(0xFF3A3428), Color(0xFF241F18)],
    'pure_black': [Color(0xFF221E16), Color(0xFF0A0906)],
  },
  'cool': {
    'bright': [Color(0xFFDCEBF5), Color(0xFFBCD5E8)],
    'dark': [Color(0xFF22303E), Color(0xFF151C24)],
    'pure_black': [Color(0xFF10171E), Color(0xFF05080B)],
  },
  'dark': {
    'bright': [Color(0xFFC9D4DE), Color(0xFFA8B4C4)],
    'dark': [Color(0xFF1E242E), Color(0xFF12161E)],
    'pure_black': [Color(0xFF0E1116), Color(0xFF04050A)],
  },
};

/// 获取壁纸兜底渐变（无照片 uri 时调用）
List<Color> getWallpaperFallback(WallpaperPreset? wallpaper, String themeId) {
  final tone = wallpaper?.tone ?? 'warm';
  return wallpaperFallback[tone]?[themeId] ?? wallpaperFallback['warm']!['bright']!;
}

/// 皮肤系统 Provider（全局主题状态）
class SkinSystem extends ChangeNotifier {
  String _themeId = 'bright';
  WallpaperPreset? _wallpaper;

  String get themeId => _themeId;
  ThemePreset get currentTheme => themes[_themeId]!;
  ThemeVars get colors => currentTheme.vars;
  WallpaperPreset? get wallpaper => _wallpaper;

  /// 切换主题（明亮/深邃/极夜）
  void setTheme(String id) {
    if (themes.containsKey(id)) {
      _themeId = id;
      notifyListeners();
    }
  }

  /// 切换壁纸
  void setWallpaper(WallpaperPreset? preset) {
    _wallpaper = preset;
    notifyListeners();
  }

  /// 当前壁纸兜底渐变色
  List<Color> get wallpaperGradient => getWallpaperFallback(_wallpaper, _themeId);

  /// 当前遮罩色
  Color get scrimColor => colors.wallpaperScrim;
}
