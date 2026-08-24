import 'package:flutter/material.dart';

/// 星巴克进度指示组件
///
/// 包含两种进度指示器：
/// - [SbLinearProgress]：细线进度条（4px 高度，圆角）
/// - [SbRingProgress]：环形进度（stroke 6，圆帽，中心百分比）
///
/// 颜色规范：
/// - 前景：Green Accent #00754A
/// - 轨道：ceramic #edebe9（细线）/ #e6e6e6（环形）
///
/// 动画规范：
/// - 细线进度条：200ms ease
/// - 环形进度：400ms ease

/// 细线进度条：高 4px 胶囊，填充 Green Accent，轨道 ceramic
///
/// 用于 `dashboard_page.dart`（统计卡进度）、`home_screen.dart`（今日目标细线条）、
/// `learn_page.dart` / `review_session.dart`（会话答题进度条）。
///
/// 示例：
/// ```dart
/// SbLinearProgress(value: 0.72) // 72% 进度
/// ```
class SbLinearProgress extends StatelessWidget {
  /// 进度值，范围 0.0 到 1.0
  final double value;

  /// 前景颜色，默认为 Green Accent #00754A
  final Color? color;

  /// 轨道背景颜色，默认为 ceramic #edebe9
  final Color? backgroundColor;

  /// 高度，默认为 4px
  final double height;

  const SbLinearProgress({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
        builder: (_, v, __) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: backgroundColor ?? const Color(0xFFEDEBE9),
          color: color ?? const Color(0xFF00754A),
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

  /// 前景颜色，默认为 Green Accent #00754A
  final Color? color;

  /// 轨道背景颜色，默认为 #e6e6e6
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 400),
      curve: Curves.ease,
      builder: (_, v, __) => Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              color: color ?? const Color(0xFF00754A),
              backgroundColor: backgroundColor ?? const Color(0xFFE6E6E6),
            ),
          ),
          Text(
            label,
            style: labelStyle ??
                const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xDE000000), // 黑 87
                ),
          ),
        ],
      ),
    );
  }
}
