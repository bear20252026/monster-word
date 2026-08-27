// Monster Word — 星巴克胶囊按钮组件
// 来源规格：docs/component_spec.md §1（PillButton）
// 50px 高度，全胶囊圆角，四变体，包装 ScaleDownOnPress 按压反馈

import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import '../tokens/starbucks_tokens.dart';
import 'scale_down_on_press.dart';

/// 星巴克胶囊按钮变体
enum SbButtonVariant {
  /// 主款：填充 #00754A + 白字
  primary,

  /// 描边款：透明底 + 绿框绿字
  outlined,

  /// 深绿底款：#1E3932 底 + 白字（深色主题/沉浸区用）
  dark,

  /// 反白款：白底 + #00754A 字（深色背景上的 CTA）
  inverse,
}

/// 星巴克胶囊按钮
///
/// 50px 高度，全胶囊圆角，支持四变体：
/// - [SbButtonVariant.primary]：绿底白字（默认）
/// - [SbButtonVariant.outlined]：绿描边绿字
/// - [SbButtonVariant.dark]：深绿底白字
/// - [SbButtonVariant.inverse]：白底深绿字
///
/// 按压反馈由 [ScaleDownOnPress] 提供（scale 0.95 + 200ms easeOut）。
///
/// 用法：
/// ```dart
/// SbButton(
///   label: '开始学习',
///   onTap: () => print('tapped'),
/// )
///
/// SbButton.outlined(
///   label: '取消',
///   onTap: () => Navigator.pop(context),
/// )
/// ```
class SbButton extends StatelessWidget {
  /// 按钮文字
  final String label;

  /// 点击回调。null 时按钮禁用。
  final VoidCallback? onTap;

  /// 按钮变体，默认 primary
  final SbButtonVariant variant;

  /// 自定义填充色（覆盖变体默认值）
  final Color? fillColor;

  /// 自定义文字色（覆盖变体默认值）
  final Color? textColor;

  /// 自定义描边（覆盖变体默认值）
  final BorderSide? borderSide;

  /// 是否禁用（叠加在 onTap==null 之上）
  final bool enabled;

  /// 最小宽度（默认不限制）
  final double? minWidth;

  /// 内边距（默认 竖10 × 横20）
  final EdgeInsetsGeometry padding;

  const SbButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = SbButtonVariant.primary,
    this.fillColor,
    this.textColor,
    this.borderSide,
    this.enabled = true,
    this.minWidth,
    this.padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
  });

  /// 便捷构造：描边款
  const SbButton.outlined({
    super.key,
    required this.label,
    this.onTap,
    this.fillColor,
    this.textColor,
    this.borderSide,
    this.enabled = true,
    this.minWidth,
    this.padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
  }) : variant = SbButtonVariant.outlined;

  /// 便捷构造：深绿底款
  const SbButton.dark({
    super.key,
    required this.label,
    this.onTap,
    this.fillColor,
    this.textColor,
    this.borderSide,
    this.enabled = true,
    this.minWidth,
    this.padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
  }) : variant = SbButtonVariant.dark;

  /// 便捷构造：反白款
  const SbButton.inverse({
    super.key,
    required this.label,
    this.onTap,
    this.fillColor,
    this.textColor,
    this.borderSide,
    this.enabled = true,
    this.minWidth,
    this.padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
  }) : variant = SbButtonVariant.inverse;

  // ---- 星巴克品牌色常量 ----
  static const Color _houseGreen = Color(0xFF00754A);
  static const Color _darkGreen = Color(0xFF1E3932);

  /// 获取当前变体的描边
  BorderSide get _defaultBorderSide {
    switch (variant) {
      case SbButtonVariant.primary:
        return const BorderSide(color: _houseGreen, width: 1);
      case SbButtonVariant.outlined:
        return const BorderSide(color: _houseGreen, width: 1);
      case SbButtonVariant.dark:
        return BorderSide.none;
      case SbButtonVariant.inverse:
        return BorderSide.none;
    }
  }

  /// 深色模式感知的填充色解析
  Color _resolveFillColor(ThemeVars colors) {
    switch (variant) {
      case SbButtonVariant.primary:
        return _houseGreen;
      case SbButtonVariant.outlined:
        return Colors.transparent;
      case SbButtonVariant.dark:
        // 深色画布上 #1E3932 对比度不足，深色模式下提亮至 greenSoft
        final isDark = colors.pageBg == StarbucksDarkColors.pageBg;
        return isDark ? StarbucksCreamColors.greenSoft : _darkGreen;
      case SbButtonVariant.inverse:
        return colors.cardBg; // 适配深色模式
    }
  }

  /// 深色模式感知的文字色解析
  Color _resolveTextColor(ThemeVars colors) {
    switch (variant) {
      case SbButtonVariant.primary:
        return Colors.white;
      case SbButtonVariant.outlined:
        return colors.accent; // 品牌绿适配主题
      case SbButtonVariant.dark:
        return Colors.white;
      case SbButtonVariant.inverse:
        return colors.accent;
    }
  }

  bool get _isInteractive => enabled && onTap != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    // 深色模式下动态适配变体默认色
    final resolvedFill = fillColor ?? _resolveFillColor(colors);
    final resolvedColor = textColor ?? _resolveTextColor(colors);
    final side = borderSide ?? _defaultBorderSide;

    return ScaleDownOnPress(
      onTap: _isInteractive ? onTap : null,
      enabled: enabled,
      child: AnimatedOpacity(
        opacity: _isInteractive ? 1.0 : 0.4,
        duration: MotionDurations.base,
        child: Container(
          constraints: minWidth != null ? BoxConstraints(minWidth: minWidth!) : null,
          decoration: ShapeDecoration(
            color: resolvedFill,
            shape: StadiumBorder(side: side),
          ),
          child: Padding(
            padding: padding,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.16, // -0.01em ≈ -0.16px @16px
                color: resolvedColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
