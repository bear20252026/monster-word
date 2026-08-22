// 由账号4生成
// Monster Word 设计令牌 — Mistral AI 色板 + Apple 结构
import 'package:flutter/material.dart';

/// Mistral AI 色板
class MistralColors {
  static const Color primary = Color(0xFFFA520F);
  static const Color primaryDeep = Color(0xFFCC3A05);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color sunshine300 = Color(0xFFFFD06A);
  static const Color sunshine500 = Color(0xFFFFB83E);
  static const Color sunshine700 = Color(0xFFFFA110);
  static const Color sunshine900 = Color(0xFFFF8A00);
  static const Color cream = Color(0xFFFFF8E0);
  static const Color creamLight = Color(0xFFFFFAEB);
  static const Color creamDeeper = Color(0xFFFFF0C2);
  static const Color beigeDeep = Color(0xFFE6D5A8);
  static const Color ink = Color(0xFF1F1F1F);
  static const Color inkTint = Color(0xFF3D3D3D);
  static const Color charcoal = Color(0xFF2C2C2C);
  static const Color slate = Color(0xFF4A4A4A);
  static const Color steel = Color(0xFF6A6A6A);
  static const Color stone = Color(0xFF8A8A8A);
  static const Color muted = Color(0xFFA8A8A8);
  static const Color hairline = Color(0xFFE5E5E5);
  static const Color hairlineSoft = Color(0xFFEDEDED);
  static const Color canvas = Color(0xFFFFFFFF);
  static const Color surfaceCode = Color(0xFF1C1C1E);
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color link = Color(0xFFFA520F);
}

/// 圆角
class AppleRadius {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 20;
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

/// Mistral 字体（PP Editorial Old 衬线 + Inter 无衬线）
class MistralTypography {
  static const TextStyle heroDisplay = TextStyle(
    fontFamily: 'Charter', fontSize: 64, fontWeight: FontWeight.w400,
    height: 1.10, letterSpacing: -1.0,
  );
  static const TextStyle heading1 = TextStyle(
    fontFamily: 'Charter', fontSize: 52, fontWeight: FontWeight.w400,
    height: 1.15, letterSpacing: -0.5,
  );
  static const TextStyle heading2 = TextStyle(
    fontFamily: 'Inter', fontSize: 36, fontWeight: FontWeight.w500,
    height: 1.20, letterSpacing: -0.5,
  );
  static const TextStyle heading3 = TextStyle(
    fontFamily: 'Inter', fontSize: 28, fontWeight: FontWeight.w500,
    height: 1.25,
  );
  static const TextStyle heading4 = TextStyle(
    fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w500,
    height: 1.30,
  );
  static const TextStyle heading5 = TextStyle(
    fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w500,
    height: 1.40,
  );
  static const TextStyle bodyMd = TextStyle(
    fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w400,
    height: 1.55,
  );
  static const TextStyle bodySm = TextStyle(
    fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400,
    height: 1.50,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400,
    height: 1.40,
  );
  static const TextStyle captionBold = TextStyle(
    fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600,
    height: 1.40,
  );
  static const TextStyle micro = TextStyle(
    fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500,
    height: 1.40,
  );
  static const TextStyle buttonMd = TextStyle(
    fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
    height: 1.30,
  );
}

/// 兼容旧代码别名
class AppColors {
  static const Color successGreen = MistralColors.success;
  static const Color highlightOrange = MistralColors.primary;
  static const Color errorRed = MistralColors.danger;
  static const Color black87 = MistralColors.ink;
  static const Color black54 = Color(0x8A1F1F1F);
  static const Color black12 = Color(0x1F1F1F1F);
  static const Color white100 = Color(0xFFFFFFFF);
  static const Color mainBgTop = MistralColors.cream;
  static const Color mainBgBottom = MistralColors.creamLight;
  static const Color cardBg = MistralColors.canvas;
  static const Color dividerGrey = MistralColors.hairline;
  static const Color textTertiary = MistralColors.stone;
  static const Color checkInBg = Color(0x33FFF8E0);
  static const Color checkInAccent = MistralColors.sunshine500;
  static const Color primary = MistralColors.primary;
}

class AppTypography {
  static TextStyle get heroWord => MistralTypography.heading1;
  static TextStyle get metricLg => MistralTypography.heading2;
  static TextStyle get metric => MistralTypography.heading3;
  static TextStyle get titlePage => MistralTypography.heading5;
  static TextStyle get titleCard => MistralTypography.heading4;
  static TextStyle get body => MistralTypography.bodyMd;
  static TextStyle get caption => MistralTypography.bodySm;
  static TextStyle get footnote => MistralTypography.micro;
}

class AppDimens {
  static const double learnBtnTextSize = 14;
  static const double learnMainWord = 52;
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
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 20;
  static const double card = 12;
  static const double control = 8;
  static const double glass = 0;
  static const double sheet = 24;
  static const double pill = 9999;
  static const double radiusNormal = 8;
}

class AppGlass {
  static const double blur = 0;
  static const double blurStrong = 0;
}

class AppUnderline {
  static const double thickness = 2;
}

enum ZIndex {
  wallpaper(0), scrim(1), content(2), tabBar(3), modal(4), guide(5);
  const ZIndex(this.value);
  final int value;
}
