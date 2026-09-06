// Monster Word — 11 套颜色主题预设（底层色板，兼容保留）。
// 用户界面只暴露 kMwStyles 里的 6 个精选风格；本文件是色板数据层。
// 单一事实来源：星巴克双主题字段引用 starbucks_tokens.dart（守卫测试锁定）。

import 'package:flutter/material.dart';

import 'package:word_app/theme/theme_vars.dart';
import 'package:word_app/tokens/starbucks_tokens.dart';

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

/// 三档主题配色
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
      pageBg: const Color(0xFFF5F5F5), // 亮色背景
      cardBg: const Color(0xFFFFFFFF), // 白色卡片
      cardBgAlt: const Color(0xFFF5F5F5),
      text1: const Color(0xDE000000), // 87% 黑（主文字）
      text2: const Color(0x8A000000), // 54% 黑（次文字）
      text3: const Color(0x9E000000), // 62% 黑（WCAG AA 达标）
      divider: const Color(0x14000000), // 8% 黑（分割线）
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
      pageBg: const Color(0xFF212532), // 深色背景（深蓝灰）
      cardBg: const Color(0xFF2E344A), // 深色卡片（蓝灰）
      cardBgAlt: const Color(0xFF292F44), // 前景色
      text1: const Color(0xDEFFFFFF), // 87% 白（主文字）
      text2: const Color(0x8AFFFFFF), // 54% 白（次文字）
      text3: const Color(0x9EFFFFFF), // 62% 白（WCAG AA 达标，与 pure_black 一致）
      divider: const Color(0x33FFFFFF), // 20% 白（分割线）
      accent: const Color(0xFFFFAB00), // 明亮琥珀色（WCAG AA 7.28:1）
      success: const Color(0xFF22A18B), // 深色成功（青绿）
      danger: const Color(0xFFFF5252), // 亮红色（WCAG AA 4.72:1）
      teal: const Color(0xFF4A90E2), // 系统文字色（蓝）
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
      pageBg: const Color(0xFF040404), // 极夜背景
      cardBg: const Color(0xFF1A1B1C), // 极夜卡片
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
    // 单一事实来源：全部字段引用 starbucks_tokens 常量（守卫测试 theme_token_consistency_test.dart 锁定）
    vars: ThemeVars(
      pageBg: StarbucksCreamColors.pageBg, // 奶油画布
      cardBg: StarbucksCreamColors.cardBg, // 白卡片
      cardBgAlt: StarbucksCreamColors.cardBgAlt, // 陶瓷画布
      text1: StarbucksCreamColors.text1, // α=0.87 正文黑
      text2: StarbucksCreamColors.text2, // α=0.70（WCAG AA on 奶油画布 5.55:1）
      text3: StarbucksCreamColors.text3, // α=0.70（WCAG AA on 奶油画布 4.71:1）
      divider: StarbucksCreamColors.divider, // 8% 黑
      accent: StarbucksCreamColors.accent, // 深星巴克绿（WCAG AA on 奶油画布 ≥5.0:1）
      success: StarbucksCreamColors.success, // 深绿色（WCAG AA）
      danger: StarbucksCreamColors.danger, // 深红色（WCAG AA）
      teal: StarbucksCreamColors.teal, // 品牌绿替代蓝（WCAG AA ≥5.0:1）
      tabBarIcon: StarbucksCreamColors.tabBarIcon, // 同 text1
      onGlassText1: StarbucksCreamColors.onGlassText1,
      onGlassText2: StarbucksCreamColors.onGlassText2, // α=0.65（WCAG AA on 白卡片）
      onGlassAccent: StarbucksCreamColors.onGlassAccent, // 深绿字（WCAG AA on 白玻璃 ≥5.0:1）
      glassBg: StarbucksCreamColors.glassBg,
      glassBgStrong: StarbucksCreamColors.glassBgStrong,
      glassBorder: StarbucksCreamColors.glassBorder,
      wallpaperScrim: StarbucksCreamColors.wallpaperScrim, // 同 pageBg
      modalGlassBg: StarbucksCreamColors.modalGlassBg,
      modalText1: StarbucksCreamColors.modalText1,
      modalText2: StarbucksCreamColors.modalText2, // α=0.65（WCAG AA on 白底）
      quizCorrectBg: StarbucksCreamColors.quizCorrectBg,
      quizCorrectText: StarbucksCreamColors.quizCorrectText, // 深绿色（WCAG AA on #D1FAE5）
      quizWrongBg: StarbucksCreamColors.quizWrongBg,
      quizWrongText: StarbucksCreamColors.quizWrongText, // 深红色（WCAG AA on #FEE2E2）
      vipGoldBg: StarbucksCreamColors.vipGoldBg, // 品牌金
      vipGoldText: StarbucksCreamColors.vipGoldText, // 深绿字（WCAG AA 5.22:1 on 金底）
      profileDecor: StarbucksCreamColors.profileDecor, // 浅绿+陶瓷
    ),
  ),
  'starbucks_dark': ThemePreset(
    id: 'starbucks_dark',
    name: '星巴克深绿',
    uiBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    // 单一事实来源：全部字段引用 starbucks_tokens 常量（守卫测试 theme_token_consistency_test.dart 锁定）
    vars: ThemeVars(
      pageBg: StarbucksDarkColors.pageBg, // 墨绿近黑
      cardBg: StarbucksDarkColors.cardBg, // 深绿表面
      cardBgAlt: StarbucksDarkColors.cardBgAlt, // 二级浮层
      text1: StarbucksDarkColors.text1, // 87% 白
      text2: StarbucksDarkColors.text2, // 雾绿（A11y 修正，固定色值）
      text3: StarbucksDarkColors.text3, // α=0.62（WCAG AA 达标）
      divider: StarbucksDarkColors.divider, // 12% 白
      accent: StarbucksDarkColors.accent, // 亮绿色（WCAG AA on 表面 4.62:1）
      success: StarbucksDarkColors.success, // 亮绿色（WCAG AA）
      danger: StarbucksDarkColors.danger, // 亮红色（WCAG AA）
      teal: StarbucksDarkColors.teal, // 蓝色（WCAG AA）
      tabBarIcon: StarbucksDarkColors.tabBarIcon,
      onGlassText1: StarbucksDarkColors.onGlassText1,
      onGlassText2: StarbucksDarkColors.onGlassText2, // 同 text2
      onGlassAccent: StarbucksDarkColors.onGlassAccent, // 白字（在绿色按钮上清晰可读）
      glassBg: StarbucksDarkColors.glassBg,
      glassBgStrong: StarbucksDarkColors.glassBgStrong,
      glassBorder: StarbucksDarkColors.glassBorder,
      wallpaperScrim: StarbucksDarkColors.wallpaperScrim,
      modalGlassBg: StarbucksDarkColors.modalGlassBg,
      modalText1: StarbucksDarkColors.modalText1,
      modalText2: StarbucksDarkColors.modalText2,
      quizCorrectBg: StarbucksDarkColors.quizCorrectBg,
      quizCorrectText: StarbucksDarkColors.quizCorrectText, // 浅青绿色（WCAG AA on #1A3D2E）
      quizWrongBg: StarbucksDarkColors.quizWrongBg,
      quizWrongText: StarbucksDarkColors.quizWrongText, // 亮红色（WCAG AA on #3D1A2E）
      vipGoldBg: StarbucksDarkColors.vipGoldBg, // 品牌金
      vipGoldText: StarbucksDarkColors.vipGoldText, // 深绿字（WCAG AA on 金底）
      profileDecor: StarbucksDarkColors.profileDecor, // 深绿体系
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
