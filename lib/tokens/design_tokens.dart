// 由账号4生成
// Apple Design Language 2026 全局设计令牌
// 来源：getdesign Apple DESIGN.md
// 规则：所有页面禁止直写十六进制，只用这些常量

import 'package:flutter/material.dart';

/// Apple 色板（DESIGN.md colors）
class AppleColors {
  // 主色
  static const Color primary = Color(0xFF0066CC);       // Action Blue
  static const Color primaryFocus = Color(0xFF0071E3);   // Focus Blue
  static const Color primaryOnDark = Color(0xFF2997FF);  // 深色底蓝

  // 文字
  static const Color ink = Color(0xFF1D1D1F);            // 主文字黑
  static const Color inkMuted80 = Color(0xFF333333);     // 80% 灰
  static const Color inkMuted48 = Color(0xFF7A7A7A);     // 48% 灰
  static const Color body = Color(0xFF1D1D1F);           // 正文
  static const Color bodyOnDark = Color(0xFFFFFFFF);     // 深色底文字
  static const Color bodyMuted = Color(0xFFCCCCCC);      // 浅灰

  // 分隔
  static const Color dividerSoft = Color(0xFFF0F0F0);    // 柔和分隔
  static const Color hairline = Color(0xFFE0E0E0);       // 细线

  // 画布
  static const Color canvas = Color(0xFFFFFFFF);         // 白底
  static const Color canvasParchment = Color(0xFFF5F5F7); // 羊皮纸
  static const Color surfacePearl = Color(0xFFFAFAFC);   // 珍珠白

  // 深色
  static const Color surfaceTile1 = Color(0xFF272729);   // 深色瓦片1
  static const Color surfaceTile2 = Color(0xFF2A2A2C);   // 深色瓦片2
  static const Color surfaceTile3 = Color(0xFF252527);   // 深色瓦片3
  static const Color surfaceBlack = Color(0xFF000000);    // 纯黑

  // 半透明
  static const Color chipTranslucent = Color(0xFFD2D2D7); // 半透明芯片
  static const Color onPrimary = Color(0xFFFFFFFF);       // 主色上文字
  static const Color onDark = Color(0xFFFFFFFF);          // 深色上文字

  // 功能色
  static const Color success = Color(0xFF30D158);         // 成功绿
  static const Color danger = Color(0xFFFF453A);          // 危险红
  static const Color warning = Color(0xFFFF9F0A);         // 警告橙
  static const Color badgeRed = Color(0xFFFF3B30);        // 红点
}

/// Apple 字阶（DESIGN.md typography）
class AppleTypography {
  // hero-display: 56px/600/-0.28
  static const TextStyle heroDisplay = TextStyle(
    fontFamily: 'SF Pro Display, system-ui, -apple-system, sans-serif',
    fontSize: 56, fontWeight: FontWeight.w600, height: 1.07,
    letterSpacing: -0.28,
  );
  // display-lg: 40px/600/1.1
  static const TextStyle displayLg = TextStyle(
    fontFamily: 'SF Pro Display, system-ui, -apple-system, sans-serif',
    fontSize: 40, fontWeight: FontWeight.w600, height: 1.1,
  );
  // display-md: 34px/600/1.47
  static const TextStyle displayMd = TextStyle(
    fontFamily: 'SF Pro Text, system-ui, -apple-system, sans-serif',
    fontSize: 34, fontWeight: FontWeight.w600, height: 1.47,
    letterSpacing: -0.374,
  );
  // tagline: 21px/600
  static const TextStyle tagline = TextStyle(
    fontFamily: 'SF Pro Display, system-ui, -apple-system, sans-serif',
    fontSize: 21, fontWeight: FontWeight.w600, height: 1.19,
    letterSpacing: 0.231,
  );
  // body-strong: 17px/600
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: 'SF Pro Text, system-ui, -apple-system, sans-serif',
    fontSize: 17, fontWeight: FontWeight.w600, height: 1.24,
    letterSpacing: -0.374,
  );
  // body: 17px/400
  static const TextStyle body = TextStyle(
    fontFamily: 'SF Pro Text, system-ui, -apple-system, sans-serif',
    fontSize: 17, fontWeight: FontWeight.w400, height: 1.47,
    letterSpacing: -0.374,
  );
  // caption: 14px/400
  static const TextStyle caption = TextStyle(
    fontFamily: 'SF Pro Text, system-ui, -apple-system, sans-serif',
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.43,
    letterSpacing: -0.224,
  );
  // caption-strong: 14px/600
  static const TextStyle captionStrong = TextStyle(
    fontFamily: 'SF Pro Text, system-ui, -apple-system, sans-serif',
    fontSize: 14, fontWeight: FontWeight.w600, height: 1.29,
    letterSpacing: -0.224,
  );
  // button-large: 18px/300
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: 'SF Pro Text, system-ui, -apple-system, sans-serif',
    fontSize: 18, fontWeight: FontWeight.w300, height: 1.0,
  );
  // button-utility: 14px/400
  static const TextStyle buttonUtility = TextStyle(
    fontFamily: 'SF Pro Text, system-ui, -apple-system, sans-serif',
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.29,
    letterSpacing: -0.224,
  );
  // fine-print: 12px/400
  static const TextStyle finePrint = TextStyle(
    fontFamily: 'SF Pro Text, system-ui, -apple-system, sans-serif',
    fontSize: 12, fontWeight: FontWeight.w400, height: 1.0,
    letterSpacing: -0.12,
  );
  // nav-link: 12px/400
  static const TextStyle navLink = TextStyle(
    fontFamily: 'SF Pro Text, system-ui, -apple-system, sans-serif',
    fontSize: 12, fontWeight: FontWeight.w400, height: 1.0,
    letterSpacing: -0.12,
  );
}

/// Apple 圆角（DESIGN.md rounded）
class AppleRadius {
  static const double none = 0;
  static const double xs = 5;
  static const double sm = 8;
  static const double md = 11;
  static const double lg = 18;
  static const double pill = 9999;
  static const double radiusNormal = 11;
  static const double full = 9999;
}

/// Apple 间距（DESIGN.md spacing）
class AppleSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 17;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double section = 80;
}

/// 全局尺寸常量
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
  static const double md = 17;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double section = 80;
  static const double page = 16;
  static const double rowH = 52;
  static const double navH = 44;
}

class AppRadius {
  static const double xs = 5;
  static const double sm = 8;
  static const double md = 11;
  static const double lg = 18;
  static const double card = 11;
  static const double control = 8;
  static const double glass = 20;
  static const double sheet = 24;
  static const double pill = 9999;
}

class AppTypography {
  static const TextStyle heroWord = TextStyle(
    fontSize: 56, fontWeight: FontWeight.w600, height: 1.07, letterSpacing: -0.28,
  );
  static const TextStyle metricLg = TextStyle(
    fontSize: 40, fontWeight: FontWeight.w600, height: 1.1,
  );
  static const TextStyle metric = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w700, height: 1.25,
  );
  static const TextStyle titlePage = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w600, height: 1.24, letterSpacing: -0.374,
  );
  static const TextStyle titleCard = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600, height: 1.375,
  );
  static const TextStyle body = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w400, height: 1.47, letterSpacing: -0.374,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.43, letterSpacing: -0.224,
  );
  static const TextStyle footnote = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400, height: 1.0, letterSpacing: -0.12,
  );
}

class AppDimens {
  static const double learnBtnTextSize = 17;
  static const double learnMainWord = 56;
  static const double learnMainWordNew = 40;
  static const double bottomBarBtnMargin = 8;
  static const double selectItemHeight = 64;
  static const double selectItemLrMargins = 16;
  static const double selectItemBottomMargins = 8;
  static const double bottomBarHeight = 56;
  static const double pageCommonMargin = 16;
  static const double radiusNormal = 11;
}

class AppGlass {
  static const double blur = 28;
  static const double blurStrong = 36;
}

class AppUnderline {
  static const double thickness = 2;
}

class AppColors {
  static const Color successGreen = Color(0xFF30D158);
  static const Color highlightOrange = Color(0xFFFF9F0A);
  static const Color errorRed = Color(0xFFFF453A);
  static const Color black87 = Color(0xDE000000);
  static const Color black54 = Color(0x8A000000);
  static const Color black12 = Color(0x1F000000);
  static const Color white100 = Color(0xFFFFFFFF);
  static const Color mainBgTop = Color(0xFFF5F5F7);
  static const Color mainBgBottom = Color(0xFFE8E8ED);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color dividerGrey = Color(0xFFE5E5EA);
  static const Color textTertiary = Color(0xFF8E8E93);
  static const Color checkInBg = Color(0x33FFFFFF);
  static const Color checkInAccent = Color(0xFFFFF8E1);
  static const Color primary = Color(0xFF0066CC);
}

enum ZIndex {
  wallpaper(0), scrim(1), content(2), tabBar(3), modal(4), guide(5);
  const ZIndex(this.value);
  final int value;
}
