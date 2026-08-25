// Monster Word — 星巴克卡片组件
// 来源规格：docs/component_spec.md §2（SbCard）
// 24px 圆角、白底、双层低透明度阴影、奶油画布浮起效果（圆润温润版）

import 'package:flutter/material.dart';
import '../theme/skin_system.dart';
import 'scale_down_on_press.dart';

/// 星巴克标准卡片组件
///
/// 24px 圆角白色卡片，带双层低透明度阴影，在奶油画布上呈现浮起效果（圆润温润）。
/// 可选 [onTap] 回调（自动包装 [ScaleDownOnPress] 按压反馈）。
///
/// 用法：
/// ```dart
/// SbCard(
///   onTap: () => print('tapped'),
///   child: Padding(
///     padding: EdgeInsets.all(16),
///     child: Text('Hello'),
///   ),
/// )
/// ```
class SbCard extends StatelessWidget {
  /// 被包装的子组件
  final Widget child;

  /// 点击回调。非 null 时自动包装 [ScaleDownOnPress] 按压反馈。
  final VoidCallback? onTap;

  /// 内边距。直接应用到 Container 的 padding。
  final EdgeInsetsGeometry? padding;

  /// 外边距。直接应用到 Container 的 margin。
  final EdgeInsetsGeometry? margin;

  /// 圆角半径，默认 24px（圆润温润版）
  final double borderRadius;

  /// 背景色，默认白色
  final Color? color;

  /// 是否启用阴影，默认 true
  final bool shadow;

  const SbCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.color,
    this.shadow = true,
  });

  /// 星巴克标准双层阴影
  static const List<BoxShadow> _shadows = [
    BoxShadow(
      color: Color(0x23000000), // rgba(0,0,0,0.14)
      blurRadius: 0.5,
      offset: Offset(0, 0),
    ),
    BoxShadow(
      color: Color(0x3D000000), // rgba(0,0,0,0.24)
      blurRadius: 1.0,
      offset: Offset(0, 1),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? colors.cardBg,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadow ? _shadows : null,
      ),
      child: child,
    );

    // 有 padding 时用 Padding 包裹（Container 的 padding 只在有 child 时有效）
    if (padding != null) {
      card = Padding(
        padding: padding!,
        child: card,
      );
    }

    // 有 onTap 时包装 ScaleDownOnPress 按压反馈
    if (onTap != null) {
      card = ScaleDownOnPress(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}
