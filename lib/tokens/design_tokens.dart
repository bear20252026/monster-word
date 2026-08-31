// Monster Word 设计令牌 — 星巴克过渡期（Batch 2 别名策略）
// 旧类名保留，内部实现指向星巴克 token
import 'package:flutter/material.dart';

import 'package:word_app/tokens/starbucks_tokens.dart';

/// 过渡期颜色（旧名新值）
class MistralColors {
  // 品牌色 → 品牌绿
  static const Color primary = StarbucksCreamColors.greenBrand; // 0xFF00754A
  static const Color primaryDeep = StarbucksCreamColors.greenHouse; // 0xFF006241
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color primaryLight = StarbucksCreamColors.greenBrand; // 0xFF00754A
  static const Color primaryDark = StarbucksDarkColors.accent; // 0xFF00A862 薄荷绿

  // sunshine 系列 → 品牌绿/金
  static const Color sunshine300 = StarbucksCreamColors.vipGoldBg; // 0xFFCBA258 品牌金
  static const Color sunshine500 = StarbucksDarkColors.accent; // 0xFF00A862 薄荷绿
  static const Color sunshine700 = StarbucksCreamColors.greenHouse; // 0xFF006241 深绿
  static const Color sunshine900 = StarbucksCreamColors.greenBrand; // 0xFF00754A 品牌绿

  // 奶油色 → 奶油画布
  static const Color cream = StarbucksCreamColors.pageBg; // 0xFFF2F0EB
  static const Color creamLight = StarbucksCreamColors.pageBg;
  static const Color creamDeeper = StarbucksCreamColors.cardBgAlt; // 0xFFEDEBE9 陶瓷
  static const Color beigeDeep = StarbucksCreamColors.profileDecor1; // 0xFFD4E9E2 浅绿

  // 深色系 → 深绿体系
  static const Color ink = Color(0xFF212121); // 正文黑
  static const Color grey500 = Color(0xFF9E9E9E); // 中性灰（对应 Material Colors.grey）
  static const Color inkTint = StarbucksCreamColors.greenBanner; // 0xFF1E3932
  static const Color charcoal = StarbucksDarkColors.pageBg; // 0xFF101B17 墨绿
  static const Color slate = StarbucksDarkColors.cardBgAlt; // 0xFF274A40 浮层绿
  static const Color steel = StarbucksDarkColors.text2; // 0xFFA9BCB5 雾绿
  static const Color stone = StarbucksDarkColors.text2;
  static const Color muted = StarbucksCreamColors.profileDecor1; // 0xFFD4E9E2 浅绿

  // 分割线 / 表面色
  static const Color hairline = StarbucksCreamColors.divider; // 0x14000000
  static const Color hairlineSoft = StarbucksCreamColors.divider;
  static const Color canvas = StarbucksCreamColors.pageBg; // 0xFFF2F0EB 奶油
  static const Color surfaceCode = StarbucksDarkColors.pageBg; // 0xFF101B17 墨绿

  // 语义色
  static const Color success = StarbucksCreamColors.success;
  static const Color successDark = StarbucksDarkColors.success;
  static const Color danger = StarbucksCreamColors.danger;
  static const Color dangerDark = StarbucksDarkColors.danger;
  static const Color error = StarbucksCreamColors.danger; // 别名，同 danger
  static const Color accent = StarbucksCreamColors.vipGoldBg; // 品牌金 accent
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6); // 蓝色 - 新词/信息
  static const Color link = StarbucksCreamColors.greenBrand; // 0xFF00754A 品牌绿

  // 透明度白/黑（用于阴影、遮罩、次要文字）
  static const Color white54 = Color(0x8AFFFFFF);
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color white24 = Color(0x3DFFFFFF);
  static const Color white15 = Color(0x26FFFFFF);
  static const Color white60 = Color(0x99FFFFFF);
  static const Color white38 = Color(0x61FFFFFF);
  static const Color white30 = Color(0x4DFFFFFF);
  static const Color black15 = Color(0x26000000);
  static const Color black26 = Color(0x42000000);
  static const Color black38 = Color(0x66000000);
  static const Color black54 = Color(0x8A000000);

  /// 深色遮罩（对应 Material Colors.black87 的透明度语义）
  static const Color scrim87 = Color(0xDD000000);
}

/// 圆角（圆润温润版）
class AppleRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double pill = 9999;
}

/// 间距
class AppleSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 64;
}

/// 字体（过渡期：指向 StarbucksTypography 的回退链）
class MistralTypography {
  // 中西文混排回退链（font_strategy.md）
  static const List<String> _fallback = ['Inter', 'PingFang SC', 'Microsoft YaHei', 'Noto Sans SC'];

  static const TextStyle heroDisplay = TextStyle(
    fontFamily: 'Charter',
    fontFamilyFallback: _fallback,
    fontSize: 64,
    fontWeight: FontWeight.w400,
    height: 1.10,
    letterSpacing: -1.0,
    color: StarbucksCreamColors.greenHouse, // 标题绿
  );
  static const TextStyle heading1 = TextStyle(
    fontFamily: 'Charter',
    fontFamilyFallback: _fallback,
    fontSize: 52,
    fontWeight: FontWeight.w400,
    height: 1.15,
    letterSpacing: -0.5,
    color: StarbucksCreamColors.greenHouse,
  );
  static const TextStyle heading2 = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 36,
    fontWeight: FontWeight.w500,
    height: 1.20,
    letterSpacing: -0.5,
    color: StarbucksCreamColors.greenHouse,
  );
  static const TextStyle heading3 = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: StarbucksCreamColors.greenHouse,
  );
  static const TextStyle heading4 = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.30,
    color: StarbucksCreamColors.greenHouse,
  );
  static const TextStyle heading5 = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.40,
    color: StarbucksCreamColors.greenHouse,
  );
  static const TextStyle bodyMd = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: StarbucksCreamColors.text1,
  );
  static const TextStyle bodySm = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.50,
    color: StarbucksCreamColors.text1,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.40,
    color: StarbucksCreamColors.text2,
  );
  static const TextStyle captionBold = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.40,
    color: StarbucksCreamColors.text1,
  );
  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: StarbucksCreamColors.text1,
  );
  static const TextStyle bodyBold = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.55,
    color: StarbucksCreamColors.text1,
  );
  static const TextStyle micro = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.40,
    color: StarbucksCreamColors.text2,
  );
  static const TextStyle buttonMd = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.30,
    color: StarbucksCreamColors.cardBg, // 白字
  );
}

/// 兼容旧代码别名（过渡期指向星巴克 token）
class AppColors {
  static const Color successGreen = MistralColors.success;
  static const Color highlightOrange = StarbucksCreamColors.greenBrand; // 品牌绿
  static const Color errorRed = MistralColors.danger;
  static const Color black87 = Color(0xFF212121); // 正文黑
  static const Color black54 = StarbucksCreamColors.text2; // α=0.58
  static const Color black12 = StarbucksCreamColors.divider; // 0x14000000
  static const Color white100 = Color(0xFFFFFFFF);
  static const Color mainBgTop = StarbucksCreamColors.pageBg; // 奶油画布
  static const Color mainBgBottom = StarbucksCreamColors.pageBg;
  static const Color cardBg = StarbucksCreamColors.cardBg; // 白卡片
  static const Color dividerGrey = StarbucksCreamColors.divider;
  static const Color textTertiary = StarbucksDarkColors.text2; // 雾绿
  static const Color checkInBg = Color(0x3300754A); // 品牌绿 20%
  static const Color checkInAccent = StarbucksDarkColors.accent; // 薄荷绿
  static const Color primary = StarbucksCreamColors.greenBrand; // 品牌绿
}

class AppTypography {
  static TextStyle get heroWord => TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: MistralTypography._fallback,
    fontSize: 38,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: StarbucksCreamColors.greenHouse, // 标题绿
  );
  static TextStyle get phonetic => TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: MistralTypography._fallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.40,
    color: StarbucksCreamColors.text2,
  );
  static TextStyle get body => MistralTypography.bodyMd;
  static TextStyle get tabActive => TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: MistralTypography._fallback,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: StarbucksCreamColors.greenBrand, // 品牌绿
  );
  static TextStyle get tabInactive => TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: MistralTypography._fallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: StarbucksCreamColors.text2,
  );
  static TextStyle get metricLg => MistralTypography.heading2;
  static TextStyle get metric => MistralTypography.heading3;
  static TextStyle get titlePage => MistralTypography.heading5;
  static TextStyle get titleCard => MistralTypography.heading4;
  static TextStyle get caption => MistralTypography.bodySm;
  static TextStyle get footnote => MistralTypography.micro;
}

class AppDimens {
  static const double learnBtnTextSize = 14;
  static const double learnMainWord = 40;
  static const double learnMainWordNew = 40;
  static const double bottomBarBtnMargin = 8;
  static const double selectItemHeight = 56;
  static const double selectItemLrMargins = 16;
  static const double selectItemBottomMargins = 8;
  static const double bottomBarHeight = 56;
  static const double pageCommonMargin = 16;
  static const double radiusNormal = 8;
}

class AppTabBar {
  static const double height = 56;
  static const double iconSize = 26;
  static const double tabletHeight = 64;
  static const double tabletIconSize = 30;
}

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 64;
  static const double page = 16;
  static const double rowH = 52;
  static const double navH = 44;
}

class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double card = 24;
  static const double control = 16;
  static const double glass = 20;
  static const double sheet = 28;
  static const double pill = 9999;
  static const double radiusNormal = 16;
}

class AppGlass {
  static const double blur = 20;
  static const double blurStrong = 40;
}

class AppUnderline {
  static const double thickness = 2;
}

enum ZIndex {
  wallpaper(0),
  scrim(1),
  content(2),
  tabBar(3),
  modal(4),
  guide(5);

  const ZIndex(this.value);
  final int value;
}
