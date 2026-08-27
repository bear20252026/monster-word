// 由 Claude 团队生成 | Monster Word App

import 'dart:math';

import 'package:flutter/material.dart';

/// Spring animation curve matching Android's SpringInterpolator.
///
/// Produces a spring-like bounce effect using an exponentially decaying
/// sinusoidal function. The [factor] controls the oscillation period
/// (default 0.4, matching the Java source).
class SpringCurve extends Curve {
  final double factor;

  const SpringCurve({this.factor = 0.4});

  @override
  double transformInternal(double t) {
    final double decay = pow(2.0, -10.0 * t).toDouble();
    return decay * sin(((t - factor / 4.0) * 2 * pi) / factor) + 1.0;
  }
}

/// Reverse spring curve — same oscillation applied in reverse.
///
/// Equivalent to applying [SpringCurve] on `1 - t`.
class ReverseSpringCurve extends Curve {
  final double factor;

  const ReverseSpringCurve({this.factor = 0.4});

  @override
  double transformInternal(double t) {
    final double f = 1.0 - t;
    final double decay = pow(2.0, -10.0 * f).toDouble();
    return decay * sin(((f - factor / 4.0) * 2 * pi) / factor) + 1.0;
  }
}

// ---------------------------------------------------------------------------
// Cubic bezier constants
// ---------------------------------------------------------------------------
// Flutter's built-in [Cubic] class uses the same Newton-Raphson approach as
// Android's CubicBezierInterpolator, so we only need the named instances.

/// Standard curve (0.29, 0.09, 0.24, 0.99) — smooth ease-out.
const Cubic standardCurve = Cubic(0.29, 0.09, 0.24, 0.99);

/// "Fatale" curve (0.0, 1.34, 1.0, 1.81) — overshoots then settles.
const Cubic fataleCurve = Cubic(0.0, 1.34, 1.0, 1.81);

/// Splash exit curve (0.4, 0.0, 0.5, 0.8) — fast ease-out for splash dismissal.
const Cubic splashExitCurve = Cubic(0.4, 0.0, 0.5, 0.8);

// ---------------------------------------------------------------------------
// Animation helper widgets
// ---------------------------------------------------------------------------

/// Wraps [child] in a horizontal shake animation (wrong-answer feedback).
/// Call [controller].forward(from: 0) to trigger.
class ShakeWidget extends AnimatedWidget {
  final Widget child;

  const ShakeWidget({super.key, required AnimationController controller, required this.child})
    : super(listenable: controller);

  Animation<double> get _offset => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(offset: Offset(_offset.value, 0), child: child);
  }
}

/// Builds the horizontal shake tween (left-right oscillation).
/// [amplitude] 抖动幅度（像素），[cycles] 周期数
Animation<double> buildShakeAnim(AnimationController controller, {double amplitude = 6.0, int cycles = 5}) {
  return TweenSequence<double>([
    for (int i = 0; i < cycles; i++) ...[
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -amplitude), weight: 1),
      TweenSequenceItem(
        tween: Tween(begin: -amplitude, end: amplitude),
        weight: 2,
      ),
      TweenSequenceItem(tween: Tween(begin: amplitude, end: 0.0), weight: 1),
    ],
  ]).animate(CurvedAnimation(parent: controller, curve: Curves.linear));
}

/// 单周期抖动偏移计算（P3: 替代 TweenSequence，更轻量）
/// 用于 AnimatedBuilder 实时计算，避免 ShakeWidget 的 listenable 类型问题
double computeShakeOffset(double t, {double amplitude = 3.0, int cycles = 1}) {
  final phase = (t * cycles * 4) % 4;
  if (phase < 1) return -amplitude * phase;
  if (phase < 3) return -amplitude + amplitude * (phase - 1);
  return amplitude - amplitude * (phase - 3);
}

/// Wraps [child] in a scale bounce animation (correct-answer feedback).
/// Call [controller].forward(from: 0) to trigger.
class BounceWidget extends AnimatedWidget {
  final Widget child;

  const BounceWidget({super.key, required AnimationController controller, required this.child})
    : super(listenable: controller);

  Animation<double> get _scale => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(scale: _scale.value, child: child);
  }
}

/// Builds the bounce tween (1.0 → 1.08 → 1.0).
Animation<double> buildBounceAnim(AnimationController controller) {
  return TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 60),
  ]).animate(CurvedAnimation(parent: controller, curve: standardCurve));
}
