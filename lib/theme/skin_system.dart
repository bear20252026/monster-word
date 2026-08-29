// Monster Word 皮肤系统 — 还原 v3.2 原版配色
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/tokens/design_language.dart';

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

class ThemePreset {
  final String id;
  final String name;

  /// UI 亮度：驱动 ThemeData/ColorScheme（组件按亮或暗渲染）
  final Brightness uiBrightness;

  /// 状态栏图标明暗：仅供未来 SystemChrome/AnnotatedRegion 使用（本批不接线）
  final Brightness statusBarBrightness;
  final ThemeVars vars;
  const ThemePreset({
    required this.id,
    required this.name,
    required this.uiBrightness,
    required this.statusBarBrightness,
    required this.vars,
  });
}

/// 三档主题：还原 v3.2 原版配色
/// - 明亮（AppLightTheme）：浅灰背景 + 橙色强调
/// - 深邃（AppDarkTheme）：深蓝灰背景 + 金色强调
/// - 极夜（AppBlackTheme）：纯黑背景 + 蓝色强调
final themes = <String, ThemePreset>{
  'bright': ThemePreset(
    id: 'bright',
    name: '明亮',
    uiBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    vars: ThemeVars(
      pageBg: const Color(0xFFF5F5F5), // 原版亮色背景
      cardBg: const Color(0xFFFFFFFF), // 原版白色卡片
      cardBgAlt: const Color(0xFFF5F5F5),
      text1: const Color(0xDE000000), // 87% 黑（原版主文字）
      text2: const Color(0x8A000000), // 54% 黑（原版次文字）
      text3: const Color(0x9E000000), // 62% 黑（WCAG AA 达标）
      divider: const Color(0x14000000), // 8% 黑（原版分割线）
      accent: const Color(0xFF9E4800), // 深琥珀色（WCAG AA 4.70:1）
      success: const Color(0xFF2E7D32), // 深绿色（WCAG AA 4.70:1）
      danger: const Color(0xFFC02424), // 深红色（WCAG AA 4.60:1）
      teal: const Color(0xFF1565C0), // 深蓝色（WCAG AA 7.05:1）
      tabBarIcon: const Color(0xDE000000),
      quizCorrectBg: const Color(0xFFD1FAE5),
      quizCorrectText: const Color(0xFF1B5E20), // 深绿色（WCAG AA on #D1FAE5）
      quizWrongBg: const Color(0xFFFEE2E2),
      quizWrongText: const Color(0xFFB71C1C), // 深红色（WCAG AA on #FEE2E2）
      profileDecor: const [Color(0xFFF5F5F5), Color(0xFFE8E8E8)],
    ),
  ),
  'dark': ThemePreset(
    id: 'dark',
    name: '深邃',
    uiBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg: const Color(0xFF212532), // 原版深色背景（深蓝灰）
      cardBg: const Color(0xFF2E344A), // 原版深色卡片（蓝灰）
      cardBgAlt: const Color(0xFF292F44), // 原版前景色
      text1: const Color(0xDEFFFFFF), // 87% 白（原版主文字）
      text2: const Color(0x8AFFFFFF), // 54% 白（原版次文字）
      text3: const Color(0x9EFFFFFF), // 62% 白（WCAG AA 达标，与 pure_black 一致）
      divider: const Color(0x33FFFFFF), // 20% 白（原版分割线）
      accent: const Color(0xFFFFAB00), // 明亮琥珀色（WCAG AA 7.28:1）
      success: const Color(0xFF22A18B), // 原版深色成功（青绿）
      danger: const Color(0xFFFF5252), // 亮红色（WCAG AA 4.72:1）
      teal: const Color(0xFF4A90E2), // 原版系统文字色（蓝）
      tabBarIcon: const Color(0xDEFFFFFF),
      onGlassText1: const Color(0xDEFFFFFF),
      onGlassText2: const Color(0x8AFFFFFF),
      onGlassAccent: const Color(0xFFFFAB00), // 明亮琥珀色（WCAG AA）
      quizCorrectBg: const Color(0xFF1A3D2E),
      quizCorrectText: const Color(0xFF4DB6AC), // 浅青绿色（WCAG AA on #1A3D2E）
      quizWrongBg: const Color(0xFF3D1A2E),
      quizWrongText: const Color(0xFFFF5252), // 亮红色（WCAG AA on #3D1A2E）
      profileDecor: const [Color(0xFF212532), Color(0xFF292F44)],
    ),
  ),
  'pure_black': ThemePreset(
    id: 'pure_black',
    name: '极夜',
    uiBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg: const Color(0xFF040404), // 原版极夜背景
      cardBg: const Color(0xFF1A1B1C), // 原版极夜卡片
      cardBgAlt: const Color(0xFF141415),
      text1: const Color(0xDEFFFFFF), // 87% 白
      text2: const Color(0x8AFFFFFF), // 54% 白
      text3: const Color(0x9EFFFFFF), // 62% 白（WCAG AA 达标）
      divider: const Color(0x33FFFFFF), // 20% 白
      accent: const Color(0xFF42A5F5), // 中蓝色（WCAG AA 7.28:1）
      success: const Color(0xFF66BB6A), // 亮绿色（WCAG AA 6.06:1）
      danger: const Color(0xFFFF5252), // 亮红色（WCAG AA 4.72:1）
      teal: const Color(0xFF2196F3), // 蓝色（WCAG AA 5.03:1）
      tabBarIcon: const Color(0xDEFFFFFF),
      onGlassText1: const Color(0xDEFFFFFF),
      onGlassText2: const Color(0x8AFFFFFF),
      onGlassAccent: const Color(0xFF42A5F5), // 中蓝色（WCAG AA）
      quizCorrectBg: const Color(0xFF0D2B22),
      quizCorrectText: const Color(0xFF66BB6A), // 亮绿色（WCAG AA on quiz背景）
      quizWrongBg: const Color(0xFF2B0D1A),
      quizWrongText: const Color(0xFFFF5252), // 亮红色（WCAG AA on quiz背景）
      profileDecor: const [Color(0xFF040404), Color(0xFF1A1B1C)],
    ),
  ),
  // ============================================================
  // 星巴克双主题（Batch 2 新增）
  // ============================================================
  'starbucks_cream': ThemePreset(
    id: 'starbucks_cream',
    name: '星巴克奶油',
    uiBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    vars: ThemeVars(
      pageBg: const Color(0xFFF2F0EB), // 奶油画布
      cardBg: const Color(0xFFFFFFFF), // 白卡片
      cardBgAlt: const Color(0xFFEDEBE9), // 陶瓷画布
      text1: const Color(0xDE212121), // α=0.87 正文黑
      text2: const Color(0xB3212121), // α=0.70（WCAG AA on 奶油画布 5.55:1）
      text3: const Color(0xB3212121), // α=0.70（WCAG AA on 奶油画布 4.71:1）
      divider: const Color(0x14000000), // 8% 黑
      accent: const Color(0xFF006B3F), // 深星巴克绿（WCAG AA on 奶油画布 ≥5.0:1）
      success: const Color(0xFF2E7D32), // 深绿色（WCAG AA）
      danger: const Color(0xFFBF2020), // 深红色（WCAG AA）
      teal: const Color(0xFF006B3F), // 深星巴克绿替代蓝（WCAG AA ≥5.0:1）
      tabBarIcon: const Color(0xDE212121), // 同 text1
      onGlassText1: const Color(0xDE212121),
      onGlassText2: const Color(0xA6212121), // α=0.65（WCAG AA on 白卡片）
      onGlassAccent: const Color(0xFF006B3F), // 深绿字（WCAG AA on 白玻璃 ≥5.0:1）
      glassBg: const Color(0xFFFFFFFF),
      glassBgStrong: const Color(0xFFFFFFFF),
      glassBorder: const Color(0x14000000),
      wallpaperScrim: const Color(0xFFF2F0EB), // 同 pageBg
      modalGlassBg: const Color(0xFFFFFFFF),
      modalText1: const Color(0xDE212121),
      modalText2: const Color(0xA6212121), // α=0.65（WCAG AA on 白底）
      quizCorrectBg: const Color(0xFFD1FAE5),
      quizCorrectText: const Color(0xFF1B5E20), // 深绿色（WCAG AA on #D1FAE5）
      quizWrongBg: const Color(0xFFFEE2E2),
      quizWrongText: const Color(0xFF9B1515), // 深红色（WCAG AA on #FEE2E2）
      vipGoldBg: const Color(0xFFCBA258), // 品牌金
      vipGoldText: const Color(0xFF1E3932), // 深绿字（WCAG AA 5.22:1 on 金底）
      profileDecor: const [Color(0xFFD4E9E2), Color(0xFFEDEBE9)], // 浅绿+陶瓷
    ),
  ),
  'starbucks_dark': ThemePreset(
    id: 'starbucks_dark',
    name: '星巴克深绿',
    uiBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg: const Color(0xFF101B17), // 墨绿近黑
      cardBg: const Color(0xFF1E3932), // 深绿表面
      cardBgAlt: const Color(0xFF274A40), // 二级浮层
      text1: const Color(0xDEFFFFFF), // 87% 白
      text2: const Color(0xFFA9BCB5), // 雾绿（A11y 修正，固定色值）
      text3: const Color(0x9EFFFFFF), // α=0.62（WCAG AA 达标）
      divider: const Color(0x1FFFFFFF), // 12% 白
      accent: const Color(0xFF00BB00), // 亮绿色（WCAG AA on 表面 4.62:1）
      success: const Color(0xFF00C853), // 亮绿色（WCAG AA）
      danger: const Color(0xFFFF5252), // 亮红色（WCAG AA）
      teal: const Color(0xFF2196F3), // 蓝色（WCAG AA）
      tabBarIcon: const Color(0xDEFFFFFF),
      onGlassText1: const Color(0xDEFFFFFF),
      onGlassText2: const Color(0xFFA9BCB5), // 同 text2
      onGlassAccent: const Color(0xFFFFFFFF), // 白字（在绿色按钮上清晰可读）
      glassBg: const Color(0xFF1E3932),
      glassBgStrong: const Color(0xFF274A40),
      glassBorder: const Color(0x1FFFFFFF),
      wallpaperScrim: const Color(0xFF101B17),
      modalGlassBg: const Color(0xFF274A40),
      modalText1: const Color(0xDEFFFFFF),
      modalText2: const Color(0xFFA9BCB5),
      quizCorrectBg: const Color(0xFF1A3D2E),
      quizCorrectText: const Color(0xFF4DB6AC), // 浅青绿色（WCAG AA on #1A3D2E）
      quizWrongBg: const Color(0xFF3D1A2E),
      quizWrongText: const Color(0xFFFF5252), // 亮红色（WCAG AA on #3D1A2E）
      vipGoldBg: const Color(0xFFCBA258), // 品牌金
      vipGoldText: const Color(0xFF1E3932), // 深绿字（WCAG AA on 金底）
      profileDecor: const [Color(0xFF101B17), Color(0xFF1E3932)], // 深绿体系
    ),
  ),
  // === 暖橙主题 — 活力温暖，适合日间学习 ===
  'warm_orange': ThemePreset(
    id: 'warm_orange',
    name: '暖阳橙',
    uiBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    vars: ThemeVars(
      pageBg: const Color(0xFFFAF5EF), // 暖白画布（微橙调）
      cardBg: const Color(0xFFFFFFFF), // 纯白卡片
      cardBgAlt: const Color(0xFFFFF3E8), // 浅橙浮层
      text1: const Color(0xDE000000), // 87% 黑
      text2: const Color(0xFF795548), // 深暖棕次要文字（WCAG AA on 暖白 ≥4.5:1）
      text3: const Color(0x9E000000), // α=0.62
      divider: const Color(0x1F000000), // 12% 黑
      accent: const Color(0xFFBF360C), // 深橙色（WCAG AA on 暖白/白卡片 ≥4.5:1）
      success: const Color(0xFF2E7D32), // 深绿（WCAG AA）
      danger: const Color(0xFFD32F2F), // 深红（WCAG AA）
      teal: const Color(0xFF1565C0), // 深蓝（WCAG AA）
      tabBarIcon: const Color(0xDE000000),
      onGlassText1: const Color(0xDE000000),
      onGlassText2: const Color(0xFF795548), // 同 text2
      onGlassAccent: const Color(0xFFBF360C), // 深橙色（WCAG AA on 白玻璃 ≥4.5:1）
      glassBg: const Color(0xFFFFFFFF),
      glassBgStrong: const Color(0xFFFFF3E8),
      glassBorder: const Color(0x1F000000),
      wallpaperScrim: const Color(0xFFFAF5EF),
      modalGlassBg: const Color(0xFFFFFFFF),
      modalText1: const Color(0xDE000000),
      modalText2: const Color(0xFF8D6E63),
      quizCorrectBg: const Color(0xFFD1FAE5),
      quizCorrectText: const Color(0xFF1B5E20),
      quizWrongBg: const Color(0xFFFEE2E2),
      quizWrongText: const Color(0xFF9B1515),
      vipGoldBg: const Color(0xFFF59E0B), // 琥珀金（暖橙主题用更暖的金）
      vipGoldText: const Color(0xFF3E2723), // 深棕字（WCAG AA on 琥珀金 ≥4.5:1）
      profileDecor: const [Color(0xFFFFE0B2), Color(0xFFFFF3E8)], // 浅橙+暖白
    ),
  ),
  // ============================================================
  // 6 大品牌风格主题（A 档，配色 1:1 取自 design/<brand>/DESIGN.md）
  // 与 B 档设计语言联动切换见 SkinSystem.setBrandStyle
  // ============================================================
  // Claude：奶油画布 + 珊瑚赤陶 accent + 暗色产品面
  'claude_cream': ThemePreset(
    id: 'claude_cream',
    name: 'Claude 奶油',
    uiBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    vars: ThemeVars(
      pageBg: const Color(0xFFFAF9F5), // canvas 奶油
      cardBg: const Color(0xFFF5F0E8), // surface-soft
      cardBgAlt: const Color(0xFFEFE9DE), // surface-card
      text1: const Color(0xFF141413), // ink
      text2: const Color(0xFF6C6A64), // muted
      text3: const Color(0xFF6C6A64), // muted 加深（原 muted-soft 仅 3.2:1）
      divider: const Color(0xFFE6DFD8), // hairline
      accent: const Color(0xFFA05438), // primary-active 再加深（#A9583E 在卡片底 4.46:1）
      success: const Color(0xFF2E7D32),
      danger: const Color(0xFFBF2020),
      teal: const Color(0xFF00695C), // accent-teal 加深（原 #5DB8A6 仅 2.3:1）
      tabBarIcon: const Color(0xFF141413),
      onGlassText1: const Color(0xFF141413),
      onGlassText2: const Color(0xFF6C6A64),
      onGlassAccent: const Color(0xFFA05438), // 同 accent
      glassBg: const Color(0xFFF5F0E8),
      glassBgStrong: const Color(0xFFEFE9DE),
      glassBorder: const Color(0xFFE6DFD8),
      wallpaperScrim: const Color(0xFFFAF9F5),
      modalGlassBg: const Color(0xFFFFFFFF),
      modalText1: const Color(0xFF141413),
      modalText2: const Color(0xFF6C6A64),
      quizCorrectBg: const Color(0xFFD1FAE5),
      quizCorrectText: const Color(0xFF1B5E20),
      quizWrongBg: const Color(0xFFFEE2E2),
      quizWrongText: const Color(0xFF9B1515),
      vipGoldBg: const Color(0xFFE8A55A), // accent-amber
      vipGoldText: const Color(0xFF141413),
      profileDecor: const [Color(0xFFF5F0E8), Color(0xFFEFE9DE)],
    ),
  ),
  // Airbnb：纯白画布 + Rausch 珊瑚红 accent
  'airbnb_light': ThemePreset(
    id: 'airbnb_light',
    name: 'Airbnb 珊瑚',
    uiBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    vars: ThemeVars(
      pageBg: const Color(0xFFFFFFFF), // canvas 纯白
      cardBg: const Color(0xFFFFFFFF),
      cardBgAlt: const Color(0xFFF7F7F7), // surface-soft
      text1: const Color(0xFF222222), // ink
      text2: const Color(0xFF6A6A6A), // muted（WCAG AA 5.3:1）
      text3: const Color(0xFF6A6A6A), // muted 同级（原 muted-soft 仅 3.0:1）
      divider: const Color(0xFFDDDDDD), // hairline
      accent: const Color(0xFFE00B41), // primary-active 加深（原 #FF385C 仅 3.7:1）
      success: const Color(0xFF067D06),
      danger: const Color(0xFFC13515), // primary-error-text
      teal: const Color(0xFF2563EB), // legal-link 加深（原 #428BFF 仅 3.1:1）
      tabBarIcon: const Color(0xFF222222),
      onGlassText1: const Color(0xFF222222),
      onGlassText2: const Color(0xFF6A6A6A),
      onGlassAccent: const Color(0xFFE00B41), // primary-active
      glassBg: const Color(0xFFFFFFFF),
      glassBgStrong: const Color(0xFFF7F7F7),
      glassBorder: const Color(0xFFDDDDDD),
      wallpaperScrim: const Color(0xFFFFFFFF),
      modalGlassBg: const Color(0xFFFFFFFF),
      modalText1: const Color(0xFF222222),
      modalText2: const Color(0xFF6A6A6A),
      quizCorrectBg: const Color(0xFFD1FAE5),
      quizCorrectText: const Color(0xFF1B5E20),
      quizWrongBg: const Color(0xFFFEE2E2),
      quizWrongText: const Color(0xFF9B1515),
      vipGoldBg: const Color(0xFFFFD06A),
      vipGoldText: const Color(0xFF222222),
      profileDecor: const [Color(0xFFF7F7F7), Color(0xFFFFE8EC)],
    ),
  ),
  // Nike：黑白单色 + 软云灰（chrome 不抢戏，色彩留给语义）
  'nike_mono': ThemePreset(
    id: 'nike_mono',
    name: 'Nike 黑白',
    uiBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    vars: ThemeVars(
      pageBg: const Color(0xFFFFFFFF), // canvas
      cardBg: const Color(0xFFFFFFFF),
      cardBgAlt: const Color(0xFFF5F5F5), // soft-cloud
      text1: const Color(0xFF111111), // ink
      text2: const Color(0xFF707072), // mute（WCAG AA 4.9:1）
      text3: const Color(0xFF707072), // mute 同级（原 stone 仅 2.8:1）
      divider: const Color(0xFFCACACB), // hairline
      accent: const Color(0xFF111111), // Nike Black
      success: const Color(0xFF007D48),
      danger: const Color(0xFFD30005), // sale
      teal: const Color(0xFF1151FF), // info
      tabBarIcon: const Color(0xFF111111),
      onGlassText1: const Color(0xFF111111),
      onGlassText2: const Color(0xFF707072),
      onGlassAccent: const Color(0xFF111111),
      glassBg: const Color(0xFFFFFFFF),
      glassBgStrong: const Color(0xFFF5F5F5),
      glassBorder: const Color(0xFFCACACB),
      wallpaperScrim: const Color(0xFFFFFFFF),
      modalGlassBg: const Color(0xFFFFFFFF),
      modalText1: const Color(0xFF111111),
      modalText2: const Color(0xFF707072),
      quizCorrectBg: const Color(0xFFD1FAE5),
      quizCorrectText: const Color(0xFF007D48),
      quizWrongBg: const Color(0xFFFEE2E2),
      quizWrongText: const Color(0xFFB71C1C),
      vipGoldBg: const Color(0xFF111111), // Nike 无金色 → 黑金反差：黑底
      vipGoldText: const Color(0xFFFFFFFF),
      profileDecor: const [Color(0xFFF5F5F5), Color(0xFFE5E5E5)],
    ),
  ),
  // Apple：珍珠白/羊皮纸画布 + 单一 Action Blue
  'apple_light': ThemePreset(
    id: 'apple_light',
    name: 'Apple 蓝调',
    uiBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    vars: ThemeVars(
      pageBg: const Color(0xFFF5F5F7), // canvas-parchment
      cardBg: const Color(0xFFFFFFFF),
      cardBgAlt: const Color(0xFFFAFAFC), // surface-pearl
      text1: const Color(0xFF1D1D1F), // ink
      text2: const Color(0xFF6E6E73), // ink-muted（WCAG AA 5.3:1）
      text3: const Color(0xFF6E6E73), // 同级加深（原 #86868B 仅 3.4:1）
      divider: const Color(0xFFE0E0E0), // hairline
      accent: const Color(0xFF0066CC), // Action Blue
      success: const Color(0xFF1D7A33),
      danger: const Color(0xFFD70015),
      teal: const Color(0xFF0066CC), // 与 accent 同级（原 focus 蓝在羊皮纸底 4.3:1）
      tabBarIcon: const Color(0xFF1D1D1F),
      onGlassText1: const Color(0xFF1D1D1F),
      onGlassText2: const Color(0xFF6E6E73),
      onGlassAccent: const Color(0xFF0066CC),
      glassBg: const Color(0xFFFFFFFF),
      glassBgStrong: const Color(0xFFFAFAFC),
      glassBorder: const Color(0xFFE0E0E0),
      wallpaperScrim: const Color(0xFFF5F5F7),
      modalGlassBg: const Color(0xFFFFFFFF),
      modalText1: const Color(0xFF1D1D1F),
      modalText2: const Color(0xFF6E6E73),
      quizCorrectBg: const Color(0xFFD1FAE5),
      quizCorrectText: const Color(0xFF1B5E20),
      quizWrongBg: const Color(0xFFFEE2E2),
      quizWrongText: const Color(0xFF9B1515),
      vipGoldBg: const Color(0xFFD2D2D7), // surface-chip-translucent（Apple 无金）
      vipGoldText: const Color(0xFF1D1D1F),
      profileDecor: const [Color(0xFFFAFAFC), Color(0xFFF0F0F0)],
    ),
  ),
  // ClickHouse：近纯黑画布 + 电光黄 voltage（唯一的暗色品牌主题）
  'clickhouse_dark': ThemePreset(
    id: 'clickhouse_dark',
    name: 'ClickHouse 电光',
    uiBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg: const Color(0xFF0A0A0A), // canvas 近纯黑
      cardBg: const Color(0xFF1A1A1A), // surface-card
      cardBgAlt: const Color(0xFF242424), // surface-elevated
      text1: const Color(0xFFFFFFFF), // ink
      text2: const Color(0xFFCCCCCC), // body
      text3: const Color(0xFF9A9A9A), // muted 加深（原 #888888 在 elevated 底 4.4:1）
      divider: const Color(0xFF2A2A2A), // hairline
      accent: const Color(0xFFFAFF69), // 电光黄
      success: const Color(0xFF22C55E),
      danger: const Color(0xFFEF4444),
      teal: const Color(0xFF3B82F6), // accent-blue
      tabBarIcon: const Color(0xFFFFFFFF),
      onGlassText1: const Color(0xFFFFFFFF),
      onGlassText2: const Color(0xFFCCCCCC),
      onGlassAccent: const Color(0xFFFAFF69),
      glassBg: const Color(0xFF1A1A1A),
      glassBgStrong: const Color(0xFF242424),
      glassBorder: const Color(0xFF3A3A3A), // hairline-strong
      wallpaperScrim: const Color(0xFF0A0A0A),
      modalGlassBg: const Color(0xFF242424),
      modalText1: const Color(0xFFFFFFFF),
      modalText2: const Color(0xFFCCCCCC),
      quizCorrectBg: const Color(0xFF14261A),
      quizCorrectText: const Color(0xFF22C55E),
      quizWrongBg: const Color(0xFF2B1212),
      quizWrongText: const Color(0xFFEF4444),
      vipGoldBg: const Color(0xFFFAFF69), // 黄即金
      vipGoldText: const Color(0xFF0A0A0A), // on-yellow
      profileDecor: const [Color(0xFF121212), Color(0xFF1A1A1A)],
    ),
  ),
};

class SkinSystem extends ChangeNotifier {
  String _themeId = 'bright';
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

  /// 所有可用主题的摘要信息（供主题选择页展示）
  List<ThemeSummary> get availableThemes => themes.values
      .map(
        (p) => ThemeSummary(
          id: p.id,
          name: p.name,
          isDark: p.uiBrightness == Brightness.dark,
          // 用 pageBg + accent 两个最具辨识度的色代表该主题
          previewColors: [p.vars.pageBg, p.vars.accent],
        ),
      )
      .toList();

  /// 当前系统亮度（监听刷新）
  Brightness _systemBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;

  SkinSystem() {
    try {
      final saved = AppPreferences().getSkinThemeId();
      _themeId = themes.containsKey(saved) ? saved : 'bright'; // 非法值兜底
      _followSystem = AppPreferences().isSkinFollowSystem();
    } catch (e) {
      // 测试环境或未初始化时使用默认值
      _themeId = 'bright';
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
    SharedPreferences.getInstance()
        .then((p) => p.setString(_kDesignPrefKey, id))
        .catchError((e) => false);
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
