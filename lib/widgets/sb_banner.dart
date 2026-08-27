// Monster Word — 星巴克深绿横幅组件
// 来源规格：docs/component_spec.md §4（FeatureBand）
// #1E3932 深绿底 + 白色文字，12px 圆角，24px 内边距
// 用于首页「连续打卡 N 天」等特性横幅场景

import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import '../tokens/starbucks_tokens.dart';
import 'scale_down_on_press.dart';

/// 星巴克深绿特性横幅
///
/// #1E3932 深绿底 + 白色文字，12px 圆角，24px 内边距。
/// 支持标题、副文案、左侧图标、右侧操作按钮。
/// 窄屏自动纵向堆叠。
///
/// 用法：
/// ```dart
/// SbBanner(
///   title: '连续打卡 7 天',
///   subtitle: '再坚持 3 天解锁本周全部奖励',
///   icon: Icon(Icons.local_fire_department, color: Colors.white, size: 32),
///   actionChild: SbButton.inverse(label: '继续学习', onTap: () {}),
///   onTap: () => print('banner tapped'),
/// )
/// ```
class SbBanner extends StatelessWidget {
  /// 主标题（24px w600 白色）
  final String title;

  /// 副文案（14px w400 白色 70% 不透明度）
  final String? subtitle;

  /// 左侧图标区域（如火焰、星星等装饰图标）
  final Widget? icon;

  /// 右侧操作区域（如 SbButton.inverse）
  final Widget? actionChild;

  /// 整个横幅的点击回调
  final VoidCallback? onTap;

  /// 背景色，默认 #1E3932 深绿
  final Color? backgroundColor;

  /// 圆角半径，默认 12px（首页内嵌横幅）
  final double borderRadius;

  /// 内边距，默认 24px
  final EdgeInsetsGeometry padding;

  const SbBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actionChild,
    this.onTap,
    this.backgroundColor,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.all(24),
  });

  /// 星巴克深绿品牌色
  static const Color _houseGreenDark = Color(0xFF1E3932);

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    // 深色模式下提亮横幅背景，避免与画布混淆
    final isDark = colors.pageBg == StarbucksDarkColors.pageBg;
    final resolvedBg = backgroundColor ?? (isDark ? StarbucksCreamColors.greenSoft : _houseGreenDark);
    // 内容区域：图标 + 文字 + 操作按钮
    Widget content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: resolvedBg, borderRadius: BorderRadius.circular(borderRadius)),
      child: _buildContent(context),
    );

    // 有 onTap 时包装按压反馈
    if (onTap != null) {
      content = ScaleDownOnPress(onTap: onTap, child: content);
    }

    return content;
  }

  /// 构建横幅内部布局
  Widget _buildContent(BuildContext context) {
    final colors = context.skin.colors;
    // 文字区域
    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: colors.onGlassText1, // 主题感知文字色
            height: 1.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: colors.onGlassText2, // 主题感知次要文字色
              height: 1.5,
            ),
          ),
        ],
      ],
    );

    // 有图标或操作按钮时用 Row 布局
    if (icon != null || actionChild != null) {
      return Row(
        children: [
          // 左侧图标
          if (icon != null) ...[icon!, const SizedBox(width: 16)],
          // 中间文字（弹性填充）
          Expanded(child: textColumn),
          // 右侧操作按钮
          if (actionChild != null) ...[const SizedBox(width: 16), actionChild!],
        ],
      );
    }

    // 纯文字横幅
    return textColumn;
  }
}
