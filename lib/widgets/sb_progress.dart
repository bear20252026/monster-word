// Monster Word — 星巴克进度指示组件
// 来源规格：docs/component_spec.md §10（SbProgress）
// 使用 ThemeVars 语义 token，支持深色模式

import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import '../tokens/motion_tokens.dart';

/// 星巴克进度指示组件
///
/// 包含两种进度指示器：
/// - [SbLinearProgress]：细线进度条（4px 高度，圆角）
/// - [SbRingProgress]：环形进度（stroke 6，圆帽，中心百分比）
///
/// 颜色规范（通过 ThemeVars 自动适配深色模式）：
/// - 前景：accent
/// - 轨道：cardBgAlt（细线）/ divider（环形）

/// 细线进度条：高 4px 胶囊，填充 accent，轨道 cardBgAlt
///
/// 用于 `dashboard_page.dart`（统计卡进度）、`home_screen.dart`（今日目标细线条）、
/// `learn_page.dart` 与正式 `review_page.dart` 的会话答题进度条。
///
/// 示例：
/// ```dart
/// SbLinearProgress(value: 0.72) // 72% 进度
/// ```
class SbLinearProgress extends StatelessWidget {
  /// 进度值，范围 0.0 到 1.0
  final double value;

  /// 前景颜色，默认为 accent
  final Color? color;

  /// 轨道背景颜色，默认为 cardBgAlt
  final Color? backgroundColor;

  /// 高度，默认为 4px
  final double height;

  const SbLinearProgress({super.key, required this.value, this.color, this.backgroundColor, this.height = 4});

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: MotionDurations.base,
        curve: Curves.ease, // motion_tokens: Curves.easeOut 可替代，保留 ease 匹配星巴克原规格
        builder: (_, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: backgroundColor ?? colors.cardBgAlt,
          color: color ?? colors.accent,
        ),
      ),
    );
  }
}

/// 环形进度：stroke 6、圆帽、中心百分比
///
/// 用于 `dashboard_page.dart`（统计卡进度环）、`splash_page.dart`（启动加载环）。
///
/// 示例：
/// ```dart
/// SbRingProgress(value: 0.72, label: '72%') // 72% 进度，中心显示 "72%"
/// ```
class SbRingProgress extends StatelessWidget {
  /// 进度值，范围 0.0 到 1.0
  final double value;

  /// 中心显示的标签文字，如 '72%'
  final String label;

  /// 前景颜色，默认为 accent
  final Color? color;

  /// 轨道背景颜色，默认为 divider
  final Color? backgroundColor;

  /// 尺寸，默认为 64x64
  final double size;

  /// 描边宽度，默认为 6
  final double strokeWidth;

  /// 中心文字样式
  final TextStyle? labelStyle;

  const SbRingProgress({
    super.key,
    required this.value,
    required this.label,
    this.color,
    this.backgroundColor,
    this.size = 64,
    this.strokeWidth = 6,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 400), // 环形进度特例档（非用户交互反馈，符合 motion_spec >800ms 环境类约束）
      curve: Curves.ease,
      builder: (_, v, _) => Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              color: color ?? colors.accent,
              backgroundColor: backgroundColor ?? colors.divider,
            ),
          ),
          Text(
            label,
            style: labelStyle ?? TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.text1),
          ),
        ],
      ),
    );
  }
}
