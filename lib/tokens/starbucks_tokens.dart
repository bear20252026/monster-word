// lib/tokens/starbucks_tokens.dart
// 星巴克双主题 Token 集 — 方案C（画布归品牌，装饰归个性）
// 来源：docs/starbucks_tokens_draft.md
import 'package:flutter/material.dart';

export 'package:word_app/tokens/motion_tokens.dart'; // 导出动效 Token

/// 星巴克奶油主题颜色（亮色）
class StarbucksCreamColors {
  // 画布层
  static const Color pageBg = Color(0xFFF2F0EB); // 奶油画布
  static const Color cardBg = Color(0xFFFFFFFF); // 白卡片
  static const Color cardBgAlt = Color(0xFFEDEBE9); // 陶瓷画布

  // 文字层
  static const Color text1 = Color(0xDE212121); // α=0.87 正文黑
  static const Color text2 = Color(0xB3212121); // α=0.70 次要文字（WCAG AA on 奶油画布 5.55:1）
  static const Color text3 = Color(0xB3212121); // α=0.70 辅助文字（WCAG AA on 奶油画布 4.71:1）

  // 品牌绿四层
  static const Color greenBrand = Color(0xFF006B3F); // CTA 绿（WCAG 深化，与 accent 统一）
  static const Color greenHouse = Color(0xFF006241); // 标题深绿
  static const Color greenBanner = Color(0xFF1E3932); // 深绿横幅
  static const Color greenSoft = Color(0xFF2B5148); // 辅助深绿

  // 强调 / 语义
  static const Color accent = Color(0xFF006B3F); // 品牌绿（WCAG AA on 奶油画布 ≥5.0:1）
  static const Color success = Color(0xFF2E7D32); // 深绿色（WCAG AA）
  static const Color danger = Color(0xFFBF2020); // 深红色（WCAG AA）
  static const Color teal = Color(0xFF006B3F); // 品牌绿替代蓝

  // 导航 / 标签
  static const Color tabBarIcon = Color(0xDE212121); // 同 text1

  // 玻璃态（亮色下与卡片同色）
  static const Color onGlassText1 = Color(0xDE212121);
  static const Color onGlassText2 = Color(0xA6212121); // α=0.65（WCAG AA on 白卡片）
  static const Color onGlassAccent = Color(0xFF006B3F);
  static const Color glassBg = Color(0xFFFFFFFF);
  static const Color glassBgStrong = Color(0xFFFFFFFF);
  static const Color glassBorder = Color(0x14000000);

  // 壁纸 / 模态
  static const Color wallpaperScrim = Color(0xFFF2F0EB);
  static const Color modalGlassBg = Color(0xFFFFFFFF);
  static const Color modalText1 = Color(0xDE212121);
  static const Color modalText2 = Color(0xA6212121); // α=0.65（WCAG AA on 白底）

  // 答题反馈
  static const Color quizCorrectBg = Color(0xFFD1FAE5);
  static const Color quizCorrectText = Color(0xFF1B5E20); // 深绿色（WCAG AA on #D1FAE5）
  static const Color quizWrongBg = Color(0xFFFEE2E2);
  static const Color quizWrongText = Color(0xFF9B1515); // 深红色（WCAG AA on #FEE2E2）

  // 成就 / 金色（仅成就场景）
  static const Color vipGoldBg = Color(0xFFCBA258);
  static const Color vipGoldText = Color(0xFF1E3932); // 深绿字（WCAG AA 5.22:1 on 金底）

  // 装饰
  static const Color profileDecor1 = Color(0xFFD4E9E2); // 浅绿
  static const Color profileDecor2 = Color(0xFFEDEBE9); // 陶瓷
  static const List<Color> profileDecor = [profileDecor1, profileDecor2];

  // 分割线
  static const Color divider = Color(0x14000000);
}

/// 星巴克深绿主题颜色（暗色）
class StarbucksDarkColors {
  // 画布层（三层深绿体系）
  static const Color pageBg = Color(0xFF101B17); // 墨绿近黑
  static const Color cardBg = Color(0xFF1E3932); // 深绿表面
  static const Color cardBgAlt = Color(0xFF274A40); // 二级浮层

  // 文字层
  static const Color text1 = Color(0xDEFFFFFF); // α=0.87
  static const Color text2 = Color(0xFFA9BCB5); // 雾绿（A11y 修正，固定色值）
  static const Color text3 = Color(0x9EFFFFFF); // α=0.62（WCAG AA 达标）

  // 强调 / 语义
  static const Color accent = Color(0xFF00BB00); // 亮绿色（WCAG AA on 表面 4.62:1）
  static const Color success = Color(0xFF00C853); // 亮绿色（WCAG AA）
  static const Color danger = Color(0xFFFF5252); // 亮红色（WCAG AA）
  static const Color teal = Color(0xFF2196F3); // 蓝色（WCAG AA）

  // 导航 / 标签
  static const Color tabBarIcon = Color(0xDEFFFFFF);

  // 玻璃态
  static const Color onGlassText1 = Color(0xDEFFFFFF);
  static const Color onGlassText2 = Color(0xFFA9BCB5); // 同 text2
  static const Color onGlassAccent = Color(0xFFFFFFFF); // 白字（在绿色按钮上清晰可读）
  static const Color glassBg = Color(0xFF1E3932);
  static const Color glassBgStrong = Color(0xFF274A40);
  static const Color glassBorder = Color(0x1FFFFFFF);

  // 壁纸 / 模态
  static const Color wallpaperScrim = Color(0xFF101B17);
  static const Color modalGlassBg = Color(0xFF274A40);
  static const Color modalText1 = Color(0xDEFFFFFF);
  static const Color modalText2 = Color(0xFFA9BCB5);

  // 答题反馈
  static const Color quizCorrectBg = Color(0xFF1A3D2E);
  static const Color quizCorrectText = Color(0xFF4DB6AC); // 浅青绿色（WCAG AA on #1A3D2E）
  static const Color quizWrongBg = Color(0xFF3D1A2E);
  static const Color quizWrongText = Color(0xFFFF5252); // 亮红色（WCAG AA on #3D1A2E）

  // 成就 / 金色
  static const Color vipGoldBg = Color(0xFFCBA258);
  static const Color vipGoldText = Color(0xFF1E3932); // 深绿字（WCAG AA on 金底）

  // 装饰
  static const Color profileDecor1 = Color(0xFF101B17);
  static const Color profileDecor2 = Color(0xFF1E3932);
  static const List<Color> profileDecor = [profileDecor1, profileDecor2];

  // 分割线
  static const Color divider = Color(0x1FFFFFFF);
}

/// 形状系统（星巴克规范）
class StarbucksShape {
  // 圆角（圆润温润版）
  static const double cardRadius = 24; // 卡片
  static const double buttonRadius = 50; // 胶囊按钮
  static const double frapRadius = 56; // Frap 悬浮按钮
  static const double inputRadius = 16; // 输入框
  static const double modalRadius = 24; // 模态框

  // 阴影（双层低透明度）
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x24000000), blurRadius: 0.5, spreadRadius: 0),
    BoxShadow(color: Color(0x3D000000), blurRadius: 1, offset: Offset(0, 1)),
  ];
}

/// 文字样式集（字体统一：不再硬编码 fontFamily，全部继承 MaterialApp 主题字体）
class StarbucksTypography {
  // 标题（绿色）
  static TextStyle get heroWord => TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: StarbucksCreamColors.greenHouse,
    letterSpacing: -0.38, // 纯西文 -0.01em
  );

  static TextStyle get heading1 => TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w400,
    height: 1.15,
    color: StarbucksCreamColors.greenHouse,
    letterSpacing: -0.52,
  );

  static TextStyle get heading2 => TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w500,
    height: 1.20,
    color: StarbucksCreamColors.greenHouse,
    letterSpacing: -0.36,
  );

  static TextStyle get heading3 =>
      TextStyle(fontSize: 28, fontWeight: FontWeight.w500, height: 1.25, color: StarbucksCreamColors.greenHouse);

  static TextStyle get heading4 =>
      TextStyle(fontSize: 22, fontWeight: FontWeight.w500, height: 1.30, color: StarbucksCreamColors.greenHouse);

  static TextStyle get heading5 =>
      TextStyle(fontSize: 18, fontWeight: FontWeight.w500, height: 1.40, color: StarbucksCreamColors.greenHouse);

  // 正文
  static TextStyle get bodyMd =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.55, color: StarbucksCreamColors.text1);

  static TextStyle get bodySm =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.50, color: StarbucksCreamColors.text1);

  static TextStyle get caption =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.40, color: StarbucksCreamColors.text2);

  static TextStyle get captionBold =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.40, color: StarbucksCreamColors.text1);

  static TextStyle get body => bodyMd;

  static TextStyle get bodyBold =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.55, color: StarbucksCreamColors.text1);

  static TextStyle get micro =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.40, color: StarbucksCreamColors.text2);

  // 按钮
  static TextStyle get buttonMd => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.30,
    color: StarbucksCreamColors.cardBg, // 白字
  );
}
