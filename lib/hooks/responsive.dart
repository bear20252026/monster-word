// 由账号4生成
// L6 自适应：断点 600dp，派生列宽/网格/玻璃卡宽/hero字号/页边距
// 翻译自 Figma useResponsive.js
// 手机/平板同构，差异仅在尺寸参数；PC端 = 平板布局

import 'package:flutter/material.dart';

import '../tokens/design_tokens.dart';

/// 自适应上下文（原版 useResponsive hook）
class AppResponsive {
  final BuildContext context;
  AppResponsive(this.context);

  double get _width => MediaQuery.sizeOf(context).width;

  /// 是否平板（≥600dp）
  bool get isTablet => _width >= ViewportTokens.breakpoint;

  /// 内容列宽（设置类页面）
  double get contentWidth => isTablet ? 600 : double.infinity;

  /// 内容列宽（学习类页面）
  double get studyContentWidth => isTablet ? 560 : double.infinity;

  /// 网格列数
  int get gridColumns => isTablet ? 3 : 2;

  /// 玻璃入口卡宽
  double get glassCardWidth => isTablet ? (_width * 0.4).clamp(160, 280) : 160;

  /// hero 字号
  double get heroFontSize => isTablet ? 56 : 44;

  /// 页边距
  double get pageMargin => isTablet ? 32 : 16;

  /// Tab 栏高度
  double get tabBarHeight => isTablet ? AppTabBar.tabletHeight : AppTabBar.height;

  /// Tab 图标大小
  double get tabIconSize => isTablet ? AppTabBar.tabletIconSize : AppTabBar.iconSize;

  /// 列表行高
  double get rowHeight => AppSpacing.rowH;

  /// 导航栏高度
  double get navHeight => AppSpacing.navH;
}

/// 快捷访问（在 Widget build 里调用 AppResponsive.of(context)）
extension ResponsiveExt on BuildContext {
  AppResponsive get responsive => AppResponsive(this);
}
