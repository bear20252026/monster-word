// 由 Claude 团队生成 | 移植自 v3.2 lock/MyElementAnimator.java
// 元素动画控制器 - 管理锁屏界面各元素的滚动动画

import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';

/// 元素动画控制器
/// 管理锁屏界面各元素（时间、电量、单词、音标等）在滚动时的视差效果
///
/// 原版 Java 使用 ValueAnimator.ofInt 从当前偏移到目标值，
/// 每帧调用 onScroll 更新 translationY / alpha。
/// Flutter 版使用 AnimationController + IntTween 实现相同行为。
class MyElementAnimator {
  final double screenHeight;
  final List<ElementDirection> directions;
  final double alphaHeight;
  final TickerProvider vsync;

  int _scrollDelta = 0;
  int _minDistance = 100;

  AnimationController? _animController;

  MyElementAnimator({
    required this.screenHeight,
    required this.directions,
    required this.vsync,
  }) : alphaHeight = screenHeight * 0.125;

  /// 处理滚动事件
  /// [delta] 垂直滚动偏移量（负值表示上滑）
  void onScroll(int delta) {
    if (delta > 0) delta = 0;
    _scrollDelta = delta;
    final absDelta = -delta;

    for (final direction in directions) {
      final translateY = (absDelta * direction.speedFactor).toDouble();
      final alpha =
          (1.0 - (translateY.abs() / alphaHeight)).clamp(0.0, 1.0);
      direction.update(translateY, alpha);
    }
  }

  /// 完成动画（解锁）
  /// 原版：ValueAnimator.ofInt(scrollDelta, -screenHeight)
  /// 动画结束后调用 [onUnlock] 并在 200ms 延迟后重置所有元素
  void finishAnimate(int speedY, {VoidCallback? onUnlock}) {
    if (speedY <= 0) speedY = 1;
    final durationMs =
        (((_scrollDelta + screenHeight) / speedY) * 1000)
            .toInt()
            .clamp(100, 1000);

    _animController?.dispose();
    _animController = AnimationController(
      duration: Duration(milliseconds: durationMs),
      vsync: vsync,
    );

    final animation = IntTween(begin: _scrollDelta, end: -screenHeight.toInt())
        .animate(_animController!);

    animation.addListener(() {
      onScroll(animation.value);
    });

    _animController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 解锁回调
        onUnlock?.call();
        // 200ms 延迟后重置所有元素（原版 postDelayed 200ms）
        Future.delayed(const Duration(milliseconds: 200), () {
          _resetAllElements();
        });
      }
    });

    _animController!.forward();
  }

  /// 回滚动画（取消解锁）
  /// 原版：ValueAnimator.ofInt(scrollDelta, 0)
  void rollbackAnimate(int speedY) {
    if (speedY <= 0) speedY = 1;
    final durationMs =
        ((-_scrollDelta / speedY) * 1000).toInt().clamp(100, 1000);

    _animController?.dispose();
    _animController = AnimationController(
      duration: Duration(milliseconds: durationMs),
      vsync: vsync,
    );

    final animation =
        IntTween(begin: _scrollDelta, end: 0).animate(_animController!);

    animation.addListener(() {
      onScroll(animation.value);
    });

    _animController!.forward();
  }

  /// 重置所有元素到初始位置（translationY=0, alpha=1）
  void _resetAllElements() {
    _scrollDelta = 0;
    for (final direction in directions) {
      direction.update(0, 1.0);
    }
  }

  void setMinDistance(int distance) {
    _minDistance = distance;
  }

  /// 当前滚动偏移量
  int get scrollDelta => _scrollDelta;

  /// 是否正在播放动画
  bool get isAnimating =>
      _animController?.isAnimating ?? false;

  /// 释放资源
  void dispose() {
    _animController?.dispose();
    _animController = null;
  }
}

/// 元素方向配置
/// [speedFactor] 视差速度因子（负值表示与滚动方向相反）
class ElementDirection {
  final double speedFactor;
  VoidCallback? _onUpdate;
  double _translateY = 0;
  double _alpha = 1.0;

  ElementDirection({required this.speedFactor, VoidCallback? onUpdate})
      : _onUpdate = onUpdate;

  void update(double translateY, double alpha) {
    _translateY = translateY;
    _alpha = alpha;
    _onUpdate?.call();
  }

  double get translateY => _translateY;
  double get alpha => _alpha;

  /// 设置更新回调（用于 State.setState）
  set onUpdate(VoidCallback? callback) => _onUpdate = callback;
}
