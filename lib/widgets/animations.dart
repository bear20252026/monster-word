// 由 Claude 团队生成 | Monster Word App

import 'package:flutter/material.dart';

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
// Animation helpers
// ---------------------------------------------------------------------------

/// Builds the bounce tween (1.0 → 1.08 → 1.0).
Animation<double> buildBounceAnim(AnimationController controller) {
  return TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 60),
  ]).animate(CurvedAnimation(parent: controller, curve: standardCurve));
}
