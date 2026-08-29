// 响应式组件库：提供跨屏幕尺寸一致的自适应行为
// 包含：响应式网格、响应式卡片、响应式文字、响应式按钮
import 'package:flutter/material.dart';

import 'package:word_app/core/presentation/responsive.dart';

/// 响应式文字：根据屏幕类型自动缩放字号
class ResponsiveText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool scaleAcrossScreens;

  const ResponsiveText(
    this.data, {
    super.key,
    this.style,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.scaleAcrossScreens = true,
  });

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    TextStyle? base = style;

    if (scaleAcrossScreens && fontSize != null) {
      base = (base ?? const TextStyle()).copyWith(fontSize: fontSize! * resp.fontScale);
    }

    if (fontWeight != null) {
      base = (base ?? const TextStyle()).copyWith(fontWeight: fontWeight);
    }

    if (color != null) {
      base = (base ?? const TextStyle()).copyWith(color: color);
    }

    return Text(data, style: base, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
  }
}

/// 响应式内边距
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final double? all;
  final double? horizontal;
  final double? vertical;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.all,
    this.horizontal,
    this.vertical,
    this.left,
    this.top,
    this.right,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    final s = resp.spacingScale;

    double? l = left ?? horizontal ?? all;
    double? t = top ?? vertical ?? all;
    double? r = right ?? horizontal ?? all;
    double? b = bottom ?? vertical ?? all;

    return Padding(
      padding: EdgeInsets.only(left: (l ?? 0) * s, top: (t ?? 0) * s, right: (r ?? 0) * s, bottom: (b ?? 0) * s),
      child: child,
    );
  }
}

/// 响应式约束容器：限制最大宽度 + 可选最小宽度
class ResponsiveConstrainedBox extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final double? minWidth;
  final Alignment alignment;

  const ResponsiveConstrainedBox({
    super.key,
    required this.child,
    this.maxWidth,
    this.minWidth,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? resp.contentMaxWidth, minWidth: minWidth ?? 0),
        child: child,
      ),
    );
  }
}

/// 响应式网格：自动根据屏幕类型选择列数
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? columns;
  final double? childAspectRatio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
    this.columns,
    this.childAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    final cols = columns ?? resp.gridColumns;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        final ratio = childAspectRatio ?? 1.0;
        final itemHeight = itemWidth / ratio;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            return SizedBox(width: itemWidth, height: itemHeight, child: child);
          }).toList(),
        );
      },
    );
  }
}

/// 响应式图标按钮
class ResponsiveIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double? size;
  final Color? color;
  final String? tooltip;

  const ResponsiveIconButton({super.key, required this.icon, this.onPressed, this.size, this.color, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    final s = size ?? 24;

    return IconButton(
      icon: Icon(icon, size: s * resp.scale),
      onPressed: onPressed,
      color: color,
      tooltip: tooltip,
      constraints: BoxConstraints(minWidth: 48 * resp.scale, minHeight: 48 * resp.scale),
    );
  }
}

/// 响应式卡片
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? mobilePadding;
  final double? tabletPadding;
  final double? desktopPadding;
  final Color? color;
  final double? elevation;
  final BorderRadius? borderRadius;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.mobilePadding,
    this.tabletPadding,
    this.desktopPadding,
    this.color,
    this.elevation,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    final p =
        padding ??
        EdgeInsets.all(
          resp.pick(mobile: mobilePadding ?? 12, tablet: tabletPadding ?? 16, desktop: desktopPadding ?? 20),
        );

    return Card(
      color: color,
      elevation: elevation,
      shape: borderRadius != null ? RoundedRectangleBorder(borderRadius: borderRadius!) : null,
      child: Padding(padding: p, child: child),
    );
  }
}

/// 响应式 SizedBox（同时支持水平和垂直）
class ResponsiveSizedBox extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget? child;

  const ResponsiveSizedBox({super.key, this.width, this.height, this.child});

  factory ResponsiveSizedBox.w(double w) => ResponsiveSizedBox(width: w);

  factory ResponsiveSizedBox.h(double h) => ResponsiveSizedBox(height: h);

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    return SizedBox(
      width: width != null ? width! * resp.scale : null,
      height: height != null ? height! * resp.scale : null,
      child: child,
    );
  }
}

/// 响应式 Flex：根据屏幕类型切换 Row/Column
class ResponsiveFlex extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double? spacing;

  /// 在桌面端使用 Row，移动端使用 Column
  final bool rowOnDesktop;

  const ResponsiveFlex({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing,
    this.rowOnDesktop = true,
  });

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    final useRow = rowOnDesktop ? resp.isDesktop : false;

    final widgets = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && spacing != null) {
        widgets.add(useRow ? SizedBox(width: spacing! * resp.scale) : SizedBox(height: spacing! * resp.scale));
      }
      widgets.add(children[i]);
    }

    if (useRow) {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: widgets,
      );
    }
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: widgets,
    );
  }
}
