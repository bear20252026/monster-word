// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 工具类：翻译自 widget/ 中的辅助类
// 文件：ScaleDownOnPressOnTouchListener, OnScrollLoadMoreListener, TextViewUtils, FlingUtils, IScrollFling, ScrollStateListener

import 'package:flutter/material.dart';
import 'animations.dart';

/// 按压缩放动画包装器（翻译自 ScaleDownOnPressOnTouchListener.java）
/// 用法：包裹任意 Widget，按下时缩小，松开时恢复
class ScaleDownOnPress extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration duration;
  final VoidCallback? onTap;

  const ScaleDownOnPress({
    super.key,
    required this.child,
    this.scale = 0.95,
    this.duration = const Duration(milliseconds: 100),
    this.onTap,
  });

  @override
  State<ScaleDownOnPress> createState() => _ScaleDownOnPressState();
}

class _ScaleDownOnPressState extends State<ScaleDownOnPress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _hasGivenUp = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: standardCurve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _hasGivenUp = false;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _releaseAnimation(triggerClick: true);
  }

  void _onTapCancel() {
    if (!_hasGivenUp) {
      _releaseAnimation(triggerClick: false);
    }
  }

  void _releaseAnimation({required bool triggerClick}) {
    _controller.reverse().then((_) {
      if (triggerClick && mounted) {
        widget.onTap?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(scale: _animation, child: widget.child),
    );
  }
}

/// 滚动加载更多监听器（翻译自 OnScrollLoadMoreListener.java）
/// 与 NotificationListener<ScrollNotification> 配合使用
class OnScrollLoadMoreNotification extends ScrollNotification {
  final VoidCallback onLoad;
  OnScrollLoadMoreNotification({
    required this.onLoad,
    required super.metrics,
    required BuildContext super.context,
  });
}

/// 可自动加载更多的滚动视图包装
class LoadMoreScrollView extends StatefulWidget {
  final Widget child;
  final VoidCallback onLoadMore;
  final bool isLoading;
  final double threshold;

  const LoadMoreScrollView({
    super.key,
    required this.child,
    required this.onLoadMore,
    this.isLoading = false,
    this.threshold = 200.0,
  });

  @override
  State<LoadMoreScrollView> createState() => _LoadMoreScrollViewState();
}

class _LoadMoreScrollViewState extends State<LoadMoreScrollView> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - widget.threshold &&
            !widget.isLoading) {
          widget.onLoadMore();
        }
        return false;
      },
      child: widget.child,
    );
  }
}

/// 文本工具（翻译自 TextViewUtils.java）
/// 提供可点击图片 Span 和可点击文本方法
class ClickableImageWidget extends StatelessWidget {
  final Widget image;
  final VoidCallback? onTap;
  final Alignment alignment;

  const ClickableImageWidget({
    super.key,
    required this.image,
    this.onTap,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: image);
  }
}

/// 惯性滚动工具（翻译自 FlingUtils.dart）
/// 计算惯性滚动距离和时长
class FlingUtils {
  static const double _inflexion = 0.35;
  static const double _decelerationRate =
      -1.7976931348623157e+308; // ln(0.78) / ln(0.9) approx

  /// 根据速度计算惯性滚动距离
  static double getSplineFlingDistance(int velocity) {
    final double l = velocity.abs() * _inflexion;
    return l * 0.5; // 简化计算
  }

  /// 根据距离反推速度
  static int getVelocityByDistance(double distance) {
    return (distance * 2).abs().toInt();
  }

  /// 计算滚动动画时长
  static Duration computeAxisDuration(int delta, int velocity, int size) {
    if (delta == 0) return Duration.zero;
    final int absDelta = delta.abs();
    final int absVelocity = velocity.abs();
    final Duration duration;
    if (absVelocity > 0) {
      duration = Duration(milliseconds: (absDelta / absVelocity * 1000).round().clamp(100, 600));
    } else {
      duration = Duration(milliseconds: ((absDelta / size + 1.0) * 256).round().clamp(100, 600));
    }
    return duration;
  }
}

/// 滚动状态监听接口（翻译自 ScrollStateListener.dart / IScrollFling.dart）
abstract class ScrollStateListener {
  void onParentScrollUpStarted(int velocity);
}

/// 可惯性滚动的接口
abstract class ScrollFlingMixin {
  void goFling(double velocity);
  double getCurrentVelocity();
  int getScrollYGo();
}
