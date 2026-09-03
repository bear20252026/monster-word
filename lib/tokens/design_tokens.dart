// Monster Word 设计令牌 — 星巴克过渡期（Batch 2 别名策略）
// 旧类名保留，内部实现指向星巴克 token
import 'package:flutter/material.dart';

import 'package:word_app/tokens/starbucks_tokens.dart';

/// 过渡期颜色（旧名新值）
class MwColors {
  // 品牌色 → 品牌绿
  static const Color primary = StarbucksCreamColors.greenBrand; // 0xFF006B3F
  static const Color primaryDeep = StarbucksCreamColors.greenHouse; // 0xFF006241
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color primaryLight = StarbucksCreamColors.greenBrand; // 0xFF006B3F
  static const Color primaryDark = StarbucksDarkColors.accent; // 0xFF00BB00 亮绿

  // sunshine 系列 → 品牌绿/金
  static const Color sunshine300 = StarbucksCreamColors.vipGoldBg; // 0xFFCBA258 品牌金
  static const Color sunshine500 = StarbucksDarkColors.accent; // 0xFF00BB00 亮绿
  static const Color sunshine700 = StarbucksCreamColors.greenHouse; // 0xFF006241 深绿
  static const Color sunshine900 = StarbucksCreamColors.greenBrand; // 0xFF006B3F 品牌绿

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
  static const Color mutedGold = Color(0xFFB0885A); // 错误态图标暗金（词典/路由错误页共用）
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6); // 蓝色 - 新词/信息
  static const Color link = StarbucksCreamColors.greenBrand; // 0xFF006B3F 品牌绿

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

/// 阴影 token（M5 收口：原 mw_card 与 5 个页面各写一遍的黑阴影字面量）
///
/// 命名对应卡片阴影三档：发丝线（0.5 blur）/ 浮起（1.0 blur + 1px 偏移）/ 柔和。
class MwShadows {
  /// 发丝线阴影 rgba(0,0,0,0.14)，blur 0.5（贴地细影）
  static const Color hairlineShadow = Color(0x23000000);

  /// 浮起阴影 rgba(0,0,0,0.24)，blur 1.0 + offset(0,1)（1px 下坠影）
  static const Color liftShadow = Color(0x3D000000);

  /// 柔和阴影 rgba(0,0,0,0.14)（同发丝线色值，独立命名便于语义区分）
  static const Color softShadow = Color(0x24000000);
}

/// 第三方平台官方品牌色（M5 收口：绑定外部品牌识别，不可跟随主题）
class ThirdPartyBrand {
  /// 微信绿（WeChat 官方品牌色）
  static const Color wechat = Color(0xFF07C160);

  /// QQ 蓝（QQ 官方品牌色）
  static const Color qq = Color(0xFF12B7F5);

  /// 微博红（Weibo 官方品牌色）
  static const Color weibo = Color(0xFFE6162D);
}

/// 错误边界深色 UI（M5 收口： mw_error_boundary 固定深色错误页专用）
///
/// 错误边界独立于主题（崩溃兜底 UI 必须不依赖 SkinSystem 可用性），故为固定深色。
class ErrorBoundaryColors {
  static const Color bg = Color(0xFF16181D); // 页面底
  static const Color panel = Color(0xFF24272D); // 内容面板
  static const Color border = Color(0xFF3A3E45); // 描边
  static const Color icon = Color(0xFF8E939B); // 图标灰
  static const Color text = Color(0xFFB0B4BA); // 正文灰
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
class MwTypography {
  static const TextStyle heroDisplay = TextStyle(
    fontFamily: 'Charter',
    fontSize: 64,
    fontWeight: FontWeight.w400,
    height: 1.10,
    letterSpacing: -1.0,
    color: StarbucksCreamColors.greenHouse, // 标题绿
  );
  static const TextStyle heading1 = TextStyle(
    fontFamily: 'Charter',
    fontSize: 52,
    fontWeight: FontWeight.w400,
    height: 1.15,
    letterSpacing: -0.5,
    color: StarbucksCreamColors.greenHouse,
  );
  static const TextStyle heading2 = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w500,
    height: 1.20,
    letterSpacing: -0.5,
    color: StarbucksCreamColors.greenHouse,
  );
  static const TextStyle heading3 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: StarbucksCreamColors.greenHouse,
  );
  static const TextStyle heading4 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.30,
    color: StarbucksCreamColors.greenHouse,
  );
  static const TextStyle heading5 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.40,
    color: StarbucksCreamColors.greenHouse,
  );
  static const TextStyle bodyMd = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: StarbucksCreamColors.text1,
  );
  static const TextStyle bodySm = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.50,
    color: StarbucksCreamColors.text1,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.40,
    color: StarbucksCreamColors.text2,
  );
  static const TextStyle captionBold = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.40,
    color: StarbucksCreamColors.text1,
  );
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: StarbucksCreamColors.text1,
  );
  static const TextStyle bodyBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.55,
    color: StarbucksCreamColors.text1,
  );
  static const TextStyle micro = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.40,
    color: StarbucksCreamColors.text2,
  );
  static const TextStyle buttonMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.30,
    color: StarbucksCreamColors.cardBg, // 白字
  );
}

/// 兼容旧代码别名（过渡期指向星巴克 token）
class AppColors {
  static const Color successGreen = MwColors.success;
  static const Color highlightOrange = StarbucksCreamColors.greenBrand; // 品牌绿
  static const Color errorRed = MwColors.danger;
  static const Color black87 = Color(0xFF212121); // 正文黑
  static const Color black54 = StarbucksCreamColors.text2; // α=0.70
  static const Color black12 = StarbucksCreamColors.divider; // 0x14000000
  static const Color white100 = Color(0xFFFFFFFF);
  static const Color mainBgTop = StarbucksCreamColors.pageBg; // 奶油画布
  static const Color mainBgBottom = StarbucksCreamColors.pageBg;
  static const Color cardBg = StarbucksCreamColors.cardBg; // 白卡片
  static const Color dividerGrey = StarbucksCreamColors.divider;
  static const Color textTertiary = StarbucksDarkColors.text2; // 雾绿
  static const Color checkInBg = Color(0x33006B3F); // 品牌绿 20%
  static const Color checkInAccent = StarbucksDarkColors.accent; // 亮绿
  static const Color primary = StarbucksCreamColors.greenBrand; // 品牌绿
}

class AppTypography {
  static TextStyle get heroWord => TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: StarbucksCreamColors.greenHouse, // 标题绿
  );
  static TextStyle get phonetic =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.40, color: StarbucksCreamColors.text2);
  static TextStyle get body => MwTypography.bodyMd;
  static TextStyle get tabActive => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: StarbucksCreamColors.greenBrand, // 品牌绿
  );
  static TextStyle get tabInactive =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: StarbucksCreamColors.text2);
  static TextStyle get metricLg => MwTypography.heading2;
  static TextStyle get metric => MwTypography.heading3;
  static TextStyle get titlePage => MwTypography.heading5;
  static TextStyle get titleCard => MwTypography.heading4;
  static TextStyle get caption => MwTypography.bodySm;
  static TextStyle get footnote => MwTypography.micro;
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
