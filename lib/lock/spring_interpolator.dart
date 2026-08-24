// 由 Claude 团队生成 | 移植自 v3.2 lock/SpringInterpolator.java
// 弹簧动画插值器

import 'dart:math';

class SpringInterpolator {
  final double factor;

  SpringInterpolator({this.factor = 0.4});

  double transform(double t) {
    return (pow(2.0, -10.0 * t) * sin((t - factor / 4.0) * 2 * pi / factor) + 1.0).toDouble();
  }
}
