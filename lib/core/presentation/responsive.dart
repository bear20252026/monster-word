// L6 自适应：断点系统 + 派生尺寸参数
// 三档适配：手机(<600) / 平板(600-1024) / 桌面(≥1024)
// 翻译自 Figma useResponsive.js
import 'package:flutter/material.dart';

import '../../tokens/design_tokens.dart';

/// 屏幕类型枚举
enum ScreenType { mobile, tablet, desktop }

/// 自适应上下文（原版 useResponsive hook）
class AppResponsive {
  final BuildContext context;
  AppResponsive(this.context);

  // === 断点 ===
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;

  double get _width => MediaQuery.sizeOf(context).width;
  double get _height => MediaQuery.sizeOf(context).height;

  /// 屏幕类型
  ScreenType get screenType {
    if (_width >= tabletBreakpoint) return ScreenType.desktop;
    if (_width >= mobileBreakpoint) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  bool get isMobile => screenType == ScreenType.mobile;
  bool get isTablet => screenType == ScreenType.tablet;
  bool get isDesktop => screenType == ScreenType.desktop;

  /// 是否平板或桌面（≥600dp）
  bool get isWide => _width >= mobileBreakpoint;

  /// 缩放系数（基于宽度的等比缩放）
  /// 基准宽度 375dp，桌面端最大放大 1.3x，平板 1.1x
  double get scale {
    if (isDesktop) return (_width / 375).clamp(1.0, 1.3);
    if (isTablet) return (_width / 375).clamp(1.0, 1.1);
    return 1.0;
  }

  /// 字号缩放（桌面端字号稍大，阅读舒适）
  double get fontScale {
    if (isDesktop) return 1.1;
    if (isTablet) return 1.05;
    return 1.0;
  }

  /// 间距缩放
  double get spacingScale => scale;

  /// 内容最大宽度（桌面端限制内容宽度，居中显示）
  double get contentMaxWidth {
    if (isDesktop) return 900;
    if (isTablet) return 720;
    return double.infinity;
  }

  /// 内容列宽（设置类页面）
  double get contentWidth => isWide ? 600 : double.infinity;

  /// 内容列宽（学习类页面）
  double get studyContentWidth => isWide ? 560 : double.infinity;

  /// 网格列数
  int get gridColumns {
    if (isDesktop) return 4;
    if (isTablet) return 3;
    return 2;
  }

  /// 词书卡片列数
  int get bookGridColumns {
    if (isDesktop) return 5;
    if (isTablet) return 4;
    return 2;
  }

  /// 玻璃入口卡宽
  double get glassCardWidth => isWide ? (_width * 0.4).clamp(160, 280) : 160;

  /// hero 字号
  double get heroFontSize => isWide ? 56 : 44;

  /// 页边距
  double get pageMargin {
    if (isDesktop) return 48;
    if (isTablet) return 32;
    return 16;
  }

  /// 水平内边距
  double get horizontalPadding {
    if (isDesktop) return 32;
    if (isTablet) return 24;
    return 16;
  }

  /// Tab 栏高度
  double get tabBarHeight => isWide ? AppTabBar.tabletHeight : AppTabBar.height;

  /// Tab 图标大小
  double get tabIconSize => isWide ? AppTabBar.tabletIconSize : AppTabBar.iconSize;

  /// 列表行高
  double get rowHeight => AppSpacing.rowH * scale;

  /// 导航栏高度
  double get navHeight => AppSpacing.navH;

  /// 圆角缩放
  double get radiusScale => scale;

  /// 根据屏幕类型选择值
  T pick<T>({required T mobile, T? tablet, T? desktop}) {
    switch (screenType) {
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.mobile:
        return mobile;
    }
  }

  /// 安全区域高度（去除状态栏和导航栏）
  double get safeHeight => _height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom;
}

/// 快捷访问（在 Widget build 里调用 AppResponsive.of(context)）
extension ResponsiveExt on BuildContext {
  AppResponsive get responsive => AppResponsive(this);
}

/// 响应式容器：自动限制最大宽度并居中
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({super.key, required this.child, this.maxWidth, this.padding});

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    final mw = maxWidth ?? resp.contentMaxWidth;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mw),
        child: padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );
  }
}

/// 响应式间距
class ResponsiveGap extends StatelessWidget {
  final double? width;
  final double? height;
  final double mobileSize;
  final double? tabletSize;
  final double? desktopSize;

  const ResponsiveGap({
    super.key,
    this.width,
    this.height,
    required this.mobileSize,
    this.tabletSize,
    this.desktopSize,
  });

  factory ResponsiveGap.h(double size, {double? tablet, double? desktop}) =>
      ResponsiveGap(width: size, mobileSize: size, tabletSize: tablet, desktopSize: desktop);

  factory ResponsiveGap.v(double size, {double? tablet, double? desktop}) =>
      ResponsiveGap(height: size, mobileSize: size, tabletSize: tablet, desktopSize: desktop);

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    final size = resp.pick(mobile: mobileSize, tablet: tabletSize, desktop: desktopSize);
    return SizedBox(width: width ?? size, height: height ?? size);
  }
}
