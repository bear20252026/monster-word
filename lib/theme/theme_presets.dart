// Monster Word — 11 套颜色主题预设（底层色板，兼容保留）。
// 用户界面只暴露 kMwStyles 里的 6 个精选风格；本文件是色板数据层。
// 单一事实来源：星巴克→starbucks_tokens；其余 9 套→skin_tokens.dart（守卫测试锁定）。

import 'package:flutter/material.dart';

import 'package:word_app/theme/theme_vars.dart';
import 'package:word_app/tokens/skin_tokens.dart';
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
      pageBg: BrightThemeColors.pageBg, // 亮色背景
      cardBg: BrightThemeColors.cardBg, // 白色卡片
      cardBgAlt: BrightThemeColors.cardBgAlt,
      text1: BrightThemeColors.text1, // 87% 黑（主文字）
      text2: BrightThemeColors.text2, // 54% 黑（次文字）
      text3: BrightThemeColors.text3, // 62% 黑（WCAG AA 达标）
      divider: BrightThemeColors.divider, // 8% 黑（分割线）
      accent: BrightThemeColors.accent, // 深琥珀色（WCAG AA 4.70:1）
      success: BrightThemeColors.success, // 深绿色（WCAG AA 4.70:1）
      danger: BrightThemeColors.danger, // 深红色（WCAG AA 4.60:1）
      teal: BrightThemeColors.teal, // 深蓝色（WCAG AA 7.05:1）
      tabBarIcon: BrightThemeColors.tabBarIcon,
      quizCorrectBg: BrightThemeColors.quizCorrectBg,
      quizCorrectText: BrightThemeColors.quizCorrectText, // 深绿色（WCAG AA on #D1FAE5）
      quizWrongBg: BrightThemeColors.quizWrongBg,
      quizWrongText: BrightThemeColors.quizWrongText, // 深红色（WCAG AA on #FEE2E2）
      profileDecor: BrightThemeColors.profileDecor,
    ),
  ),
  'dark': ThemePreset(
    id: 'dark',
    name: '深邃',
    uiBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg: DarkThemeColors.pageBg, // 深色背景（深蓝灰）
      cardBg: DarkThemeColors.cardBg, // 深色卡片（蓝灰）
      cardBgAlt: DarkThemeColors.cardBgAlt, // 前景色
      text1: DarkThemeColors.text1, // 87% 白（主文字）
      text2: DarkThemeColors.text2, // 54% 白（次文字）
      text3: DarkThemeColors.text3, // 62% 白（WCAG AA 达标，与 pure_black 一致）
      divider: DarkThemeColors.divider, // 20% 白（分割线）
      accent: DarkThemeColors.accent, // 明亮琥珀色（WCAG AA 7.28:1）
      success: DarkThemeColors.success, // 深色成功（青绿）
      danger: DarkThemeColors.danger, // 亮红色（WCAG AA 4.72:1）
      teal: DarkThemeColors.teal, // 系统文字色（蓝）
      tabBarIcon: DarkThemeColors.tabBarIcon,
      onGlassText1: DarkThemeColors.onGlassText1,
      onGlassText2: DarkThemeColors.onGlassText2,
      onGlassAccent: DarkThemeColors.onGlassAccent, // 明亮琥珀色（WCAG AA）
      quizCorrectBg: DarkThemeColors.quizCorrectBg,
      quizCorrectText: DarkThemeColors.quizCorrectText, // 浅青绿色（WCAG AA on #1A3D2E）
      quizWrongBg: DarkThemeColors.quizWrongBg,
      quizWrongText: DarkThemeColors.quizWrongText, // 亮红色（WCAG AA on #3D1A2E）
      profileDecor: DarkThemeColors.profileDecor,
    ),
  ),
  'pure_black': ThemePreset(
    id: 'pure_black',
    name: '极夜',
    uiBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg: PureBlackThemeColors.pageBg, // 极夜背景
      cardBg: PureBlackThemeColors.cardBg, // 极夜卡片
      cardBgAlt: PureBlackThemeColors.cardBgAlt,
      text1: PureBlackThemeColors.text1, // 87% 白
      text2: PureBlackThemeColors.text2, // 54% 白
      text3: PureBlackThemeColors.text3, // 62% 白（WCAG AA 达标）
      divider: PureBlackThemeColors.divider, // 20% 白
      accent: PureBlackThemeColors.accent, // 中蓝色（WCAG AA 7.28:1）
      success: PureBlackThemeColors.success, // 亮绿色（WCAG AA 6.06:1）
      danger: PureBlackThemeColors.danger, // 亮红色（WCAG AA 4.72:1）
      teal: PureBlackThemeColors.teal, // 蓝色（WCAG AA 5.03:1）
      tabBarIcon: PureBlackThemeColors.tabBarIcon,
      onGlassText1: PureBlackThemeColors.onGlassText1,
      onGlassText2: PureBlackThemeColors.onGlassText2,
      onGlassAccent: PureBlackThemeColors.onGlassAccent, // 中蓝色（WCAG AA）
      quizCorrectBg: PureBlackThemeColors.quizCorrectBg,
      quizCorrectText: PureBlackThemeColors.quizCorrectText, // 亮绿色（WCAG AA on quiz背景）
      quizWrongBg: PureBlackThemeColors.quizWrongBg,
      quizWrongText: PureBlackThemeColors.quizWrongText, // 亮红色（WCAG AA on quiz背景）
      profileDecor: PureBlackThemeColors.profileDecor,
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
      pageBg: WarmOrangeThemeColors.pageBg, // 暖白画布（微橙调）
      cardBg: WarmOrangeThemeColors.cardBg, // 纯白卡片
      cardBgAlt: WarmOrangeThemeColors.cardBgAlt, // 浅橙浮层
      text1: WarmOrangeThemeColors.text1, // 87% 黑
      text2: WarmOrangeThemeColors.text2, // 深暖棕次要文字（WCAG AA on 暖白 ≥4.5:1）
      text3: WarmOrangeThemeColors.text3, // α=0.62
      divider: WarmOrangeThemeColors.divider, // 12% 黑
      accent: WarmOrangeThemeColors.accent, // 深橙色（WCAG AA on 暖白/白卡片 ≥4.5:1）
      success: WarmOrangeThemeColors.success, // 深绿（WCAG AA）
      danger: WarmOrangeThemeColors.danger, // 深红（WCAG AA）
      teal: WarmOrangeThemeColors.teal, // 深蓝（WCAG AA）
      tabBarIcon: WarmOrangeThemeColors.tabBarIcon,
      onGlassText1: WarmOrangeThemeColors.onGlassText1,
      onGlassText2: WarmOrangeThemeColors.onGlassText2, // 同 text2
      onGlassAccent: WarmOrangeThemeColors.onGlassAccent, // 深橙色（WCAG AA on 白玻璃 ≥4.5:1）
      glassBg: WarmOrangeThemeColors.glassBg,
      glassBgStrong: WarmOrangeThemeColors.glassBgStrong,
      glassBorder: WarmOrangeThemeColors.glassBorder,
      wallpaperScrim: WarmOrangeThemeColors.wallpaperScrim,
      modalGlassBg: WarmOrangeThemeColors.modalGlassBg,
      modalText1: WarmOrangeThemeColors.modalText1,
      modalText2: WarmOrangeThemeColors.modalText2,
      quizCorrectBg: WarmOrangeThemeColors.quizCorrectBg,
      quizCorrectText: WarmOrangeThemeColors.quizCorrectText,
      quizWrongBg: WarmOrangeThemeColors.quizWrongBg,
      quizWrongText: WarmOrangeThemeColors.quizWrongText,
      vipGoldBg: WarmOrangeThemeColors.vipGoldBg, // 琥珀金（暖橙主题用更暖的金）
      vipGoldText: WarmOrangeThemeColors.vipGoldText, // 深棕字（WCAG AA on 琥珀金 ≥4.5:1）
      profileDecor: WarmOrangeThemeColors.profileDecor, // 浅橙+暖白
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
      pageBg: ClaudeCreamColors.pageBg, // canvas 奶油
      cardBg: ClaudeCreamColors.cardBg, // surface-soft
      cardBgAlt: ClaudeCreamColors.cardBgAlt, // surface-card
      text1: ClaudeCreamColors.text1, // ink
      text2: ClaudeCreamColors.text2, // muted
      text3: ClaudeCreamColors.text3, // muted 加深（原 muted-soft 仅 3.2:1）
      divider: ClaudeCreamColors.divider, // hairline
      accent: ClaudeCreamColors.accent, // primary-active 再加深（#A9583E 在卡片底 4.46:1）
      success: ClaudeCreamColors.success,
      danger: ClaudeCreamColors.danger,
      teal: ClaudeCreamColors.teal, // accent-teal 加深（原 #5DB8A6 仅 2.3:1）
      tabBarIcon: ClaudeCreamColors.tabBarIcon,
      onGlassText1: ClaudeCreamColors.onGlassText1,
      onGlassText2: ClaudeCreamColors.onGlassText2,
      onGlassAccent: ClaudeCreamColors.onGlassAccent, // 同 accent
      glassBg: ClaudeCreamColors.glassBg,
      glassBgStrong: ClaudeCreamColors.glassBgStrong,
      glassBorder: ClaudeCreamColors.glassBorder,
      wallpaperScrim: ClaudeCreamColors.wallpaperScrim,
      modalGlassBg: ClaudeCreamColors.modalGlassBg,
      modalText1: ClaudeCreamColors.modalText1,
      modalText2: ClaudeCreamColors.modalText2,
      quizCorrectBg: ClaudeCreamColors.quizCorrectBg,
      quizCorrectText: ClaudeCreamColors.quizCorrectText,
      quizWrongBg: ClaudeCreamColors.quizWrongBg,
      quizWrongText: ClaudeCreamColors.quizWrongText,
      vipGoldBg: ClaudeCreamColors.vipGoldBg, // accent-amber
      vipGoldText: ClaudeCreamColors.vipGoldText,
      profileDecor: ClaudeCreamColors.profileDecor,
    ),
  ),
  // Airbnb：纯白画布 + Rausch 珊瑚红 accent
  'airbnb_light': ThemePreset(
    id: 'airbnb_light',
    name: 'Airbnb 珊瑚',
    uiBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    vars: ThemeVars(
      pageBg: AirbnbLightColors.pageBg, // canvas 纯白
      cardBg: AirbnbLightColors.cardBg,
      cardBgAlt: AirbnbLightColors.cardBgAlt, // surface-soft
      text1: AirbnbLightColors.text1, // ink
      text2: AirbnbLightColors.text2, // muted（WCAG AA 5.3:1）
      text3: AirbnbLightColors.text3, // muted 同级（原 muted-soft 仅 3.0:1）
      divider: AirbnbLightColors.divider, // hairline
      accent: AirbnbLightColors.accent, // primary-active 加深（原 #FF385C 仅 3.7:1）
      success: AirbnbLightColors.success,
      danger: AirbnbLightColors.danger, // primary-error-text
      teal: AirbnbLightColors.teal, // legal-link 加深（原 #428BFF 仅 3.1:1）
      tabBarIcon: AirbnbLightColors.tabBarIcon,
      onGlassText1: AirbnbLightColors.onGlassText1,
      onGlassText2: AirbnbLightColors.onGlassText2,
      onGlassAccent: AirbnbLightColors.onGlassAccent, // primary-active
      glassBg: AirbnbLightColors.glassBg,
      glassBgStrong: AirbnbLightColors.glassBgStrong,
      glassBorder: AirbnbLightColors.glassBorder,
      wallpaperScrim: AirbnbLightColors.wallpaperScrim,
      modalGlassBg: AirbnbLightColors.modalGlassBg,
      modalText1: AirbnbLightColors.modalText1,
      modalText2: AirbnbLightColors.modalText2,
      quizCorrectBg: AirbnbLightColors.quizCorrectBg,
      quizCorrectText: AirbnbLightColors.quizCorrectText,
      quizWrongBg: AirbnbLightColors.quizWrongBg,
      quizWrongText: AirbnbLightColors.quizWrongText,
      vipGoldBg: AirbnbLightColors.vipGoldBg,
      vipGoldText: AirbnbLightColors.vipGoldText,
      profileDecor: AirbnbLightColors.profileDecor,
    ),
  ),
  // Nike：黑白单色 + 软云灰（chrome 不抢戏，色彩留给语义）
  'nike_mono': ThemePreset(
    id: 'nike_mono',
    name: 'Nike 黑白',
    uiBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    vars: ThemeVars(
      pageBg: NikeMonoColors.pageBg, // canvas
      cardBg: NikeMonoColors.cardBg,
      cardBgAlt: NikeMonoColors.cardBgAlt, // soft-cloud
      text1: NikeMonoColors.text1, // ink
      text2: NikeMonoColors.text2, // mute（WCAG AA 4.9:1）
      text3: NikeMonoColors.text3, // mute 同级（原 stone 仅 2.8:1）
      divider: NikeMonoColors.divider, // hairline
      accent: NikeMonoColors.accent, // Nike Black
      success: NikeMonoColors.success,
      danger: NikeMonoColors.danger, // sale
      teal: NikeMonoColors.teal, // info
      tabBarIcon: NikeMonoColors.tabBarIcon,
      onGlassText1: NikeMonoColors.onGlassText1,
      onGlassText2: NikeMonoColors.onGlassText2,
      onGlassAccent: NikeMonoColors.onGlassAccent,
      glassBg: NikeMonoColors.glassBg,
      glassBgStrong: NikeMonoColors.glassBgStrong,
      glassBorder: NikeMonoColors.glassBorder,
      wallpaperScrim: NikeMonoColors.wallpaperScrim,
      modalGlassBg: NikeMonoColors.modalGlassBg,
      modalText1: NikeMonoColors.modalText1,
      modalText2: NikeMonoColors.modalText2,
      quizCorrectBg: NikeMonoColors.quizCorrectBg,
      quizCorrectText: NikeMonoColors.quizCorrectText,
      quizWrongBg: NikeMonoColors.quizWrongBg,
      quizWrongText: NikeMonoColors.quizWrongText,
      vipGoldBg: NikeMonoColors.vipGoldBg, // Nike 无金色 → 黑金反差：黑底
      vipGoldText: NikeMonoColors.vipGoldText,
      profileDecor: NikeMonoColors.profileDecor,
    ),
  ),
  // Apple：珍珠白/羊皮纸画布 + 单一 Action Blue
  'apple_light': ThemePreset(
    id: 'apple_light',
    name: 'Apple 蓝调',
    uiBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    vars: ThemeVars(
      pageBg: AppleLightColors.pageBg, // canvas-parchment
      cardBg: AppleLightColors.cardBg,
      cardBgAlt: AppleLightColors.cardBgAlt, // surface-pearl
      text1: AppleLightColors.text1, // ink
      text2: AppleLightColors.text2, // ink-muted（WCAG AA 5.3:1）
      text3: AppleLightColors.text3, // 同级加深（原 #86868B 仅 3.4:1）
      divider: AppleLightColors.divider, // hairline
      accent: AppleLightColors.accent, // Action Blue
      success: AppleLightColors.success,
      danger: AppleLightColors.danger,
      teal: AppleLightColors.teal, // 与 accent 同级（原 focus 蓝在羊皮纸底 4.3:1）
      tabBarIcon: AppleLightColors.tabBarIcon,
      onGlassText1: AppleLightColors.onGlassText1,
      onGlassText2: AppleLightColors.onGlassText2,
      onGlassAccent: AppleLightColors.onGlassAccent,
      glassBg: AppleLightColors.glassBg,
      glassBgStrong: AppleLightColors.glassBgStrong,
      glassBorder: AppleLightColors.glassBorder,
      wallpaperScrim: AppleLightColors.wallpaperScrim,
      modalGlassBg: AppleLightColors.modalGlassBg,
      modalText1: AppleLightColors.modalText1,
      modalText2: AppleLightColors.modalText2,
      quizCorrectBg: AppleLightColors.quizCorrectBg,
      quizCorrectText: AppleLightColors.quizCorrectText,
      quizWrongBg: AppleLightColors.quizWrongBg,
      quizWrongText: AppleLightColors.quizWrongText,
      vipGoldBg: AppleLightColors.vipGoldBg, // surface-chip-translucent（Apple 无金）
      vipGoldText: AppleLightColors.vipGoldText,
      profileDecor: AppleLightColors.profileDecor,
    ),
  ),
  // ClickHouse：近纯黑画布 + 电光黄 voltage（唯一的暗色品牌主题）
  'clickhouse_dark': ThemePreset(
    id: 'clickhouse_dark',
    name: 'ClickHouse 电光',
    uiBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    vars: ThemeVars(
      pageBg: ClickhouseDarkColors.pageBg, // canvas 近纯黑
      cardBg: ClickhouseDarkColors.cardBg, // surface-card
      cardBgAlt: ClickhouseDarkColors.cardBgAlt, // surface-elevated
      text1: ClickhouseDarkColors.text1, // ink
      text2: ClickhouseDarkColors.text2, // body
      text3: ClickhouseDarkColors.text3, // muted 加深（原 #888888 在 elevated 底 4.4:1）
      divider: ClickhouseDarkColors.divider, // hairline
      accent: ClickhouseDarkColors.accent, // 电光黄
      success: ClickhouseDarkColors.success,
      danger: ClickhouseDarkColors.danger,
      teal: ClickhouseDarkColors.teal, // accent-blue
      tabBarIcon: ClickhouseDarkColors.tabBarIcon,
      onGlassText1: ClickhouseDarkColors.onGlassText1,
      onGlassText2: ClickhouseDarkColors.onGlassText2,
      onGlassAccent: ClickhouseDarkColors.onGlassAccent,
      glassBg: ClickhouseDarkColors.glassBg,
      glassBgStrong: ClickhouseDarkColors.glassBgStrong,
      glassBorder: ClickhouseDarkColors.glassBorder, // hairline-strong
      wallpaperScrim: ClickhouseDarkColors.wallpaperScrim,
      modalGlassBg: ClickhouseDarkColors.modalGlassBg,
      modalText1: ClickhouseDarkColors.modalText1,
      modalText2: ClickhouseDarkColors.modalText2,
      quizCorrectBg: ClickhouseDarkColors.quizCorrectBg,
      quizCorrectText: ClickhouseDarkColors.quizCorrectText,
      quizWrongBg: ClickhouseDarkColors.quizWrongBg,
      quizWrongText: ClickhouseDarkColors.quizWrongText,
      vipGoldBg: ClickhouseDarkColors.vipGoldBg, // 黄即金
      vipGoldText: ClickhouseDarkColors.vipGoldText, // on-yellow
      profileDecor: ClickhouseDarkColors.profileDecor,
    ),
  ),
};
