// 由账号4生成
// L1 设计令牌：全局唯一样式源（语义色/字阶/间距/圆角/玻璃/zIndex）
// 翻译自 Figma designTokens.js，校准依据：2026-08-19 手机+平板截图

import 'package:flutter/material.dart';

/// 视口基准
class ViewportTokens {
  static const double phoneWidthDp = 390;
  static const double tabletWidthDp = 1024;
  static const double breakpoint = 600;
}

/// 三档主题不变的语义色
class BrandColors {
  static const Color brand = Color(0xFFFF9500);     // 品牌橙
  static const Color badgeRed = Color(0xFFFF3B30);  // 通知红点
  static const Color vipGold = Color(0xFFC9A227);   // VIP 金
  static const Color iconTeal = Color(0xFF4ECDC4);  // 个人中心图标
  static const Color iconPurple = Color(0xFFA78BFA);
  static const Color iconBlue = Color(0xFF60A5FA);
  static const Color iconGold = Color(0xFFF5A623);  // 词书页工具栏
}

/// 字阶（原版 typography）
class AppTypography {
  // heroWord: 首页每日单词 40dp
  static const TextStyle heroWord = TextStyle(
    fontSize: 40, fontWeight: FontWeight.w700, height: 48 / 40,
  );
  // metricLg: 大数字统计 32dp
  static const TextStyle metricLg = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w700, height: 38 / 32,
  );
  // metric: 数字统计 24dp
  static const TextStyle metric = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w700, height: 30 / 24,
  );
  // titlePage: 页面标题 17dp
  static const TextStyle titlePage = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w600, height: 24 / 17,
  );
  // titleCard: 卡片标题 16dp
  static const TextStyle titleCard = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600, height: 22 / 16,
  );
  // body: 正文 15dp
  static const TextStyle body = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400, height: 21 / 15,
  );
  // caption: 辅助文字 13dp
  static const TextStyle caption = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400, height: 18 / 13,
  );
  // footnote: 脚注 12dp
  static const TextStyle footnote = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400, height: 16 / 12,
  );
}

/// 间距（原版 spacing）
class AppSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double page = 16;
  static const double rowH = 52;
  static const double navH = 44;
}

/// 圆角（原版 radius）
class AppRadius {
  static const double card = 14;
  static const double control = 8;
  static const double glass = 20;
  static const double sheet = 24;
  static const double pill = 999;
}

/// 玻璃层物理参数
class AppGlass {
  static const double blur = 28;
  static const double blurStrong = 36;
}

/// 底部 Tab 栏（Z3）
class AppTabBar {
  static const double height = 56;
  static const double iconSize = 26;
  static const double tabletHeight = 64;
  static const double tabletIconSize = 30;
  static const int tabCount = 3;
}

/// 下划线文字钮描线粗细
class AppUnderline {
  static const double thickness = 2;
}

/// Z 轴层级（全局唯一权威）
enum ZIndex {
  wallpaper(0),   // Z0 壁纸照片
  scrim(1),       // Z1 主题遮罩
  content(2),     // Z2 页面内容
  tabBar(3),      // Z3 底部 Tab 栏
  modal(4),       // Z4 模态弹窗
  guide(5);       // Z5 全屏新手教学

  const ZIndex(this.value);
  final int value;
}
