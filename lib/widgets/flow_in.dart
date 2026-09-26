// lib/widgets/flow_in.dart
// 有序流动入场：列表/网格 item 按索引波次淡入上浮（Apple 卡片廊入场编排，
// 参考 Inspira UI apple-card-carousel 的 stagger 项）。
// 用 TweenAnimationBuilder + Interval 实现 per-item 延迟，无需控制器；
// 外层键值变化（如切分类签）时重建即重放整段波次。
import 'package:flutter/material.dart';

import 'package:word_app/tokens/motion_tokens.dart';

/// 按索引依次入场的流动容器。
///
/// [index] 越大起跑越晚：每步 [step]（默认 35ms），最多 [maxStaggerSteps]
/// 步封顶，避免长列表尾部等待过久。滚动懒加载时，新入列的 item 也会自然
/// 波次入场。系统开启「减弱动态效果」时直接呈现最终态。
class FlowIn extends StatelessWidget {
  const FlowIn({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 35),
    this.maxStaggerSteps = 12,
    this.distance = 18,
  });

  final int index;
  final Widget child;

  /// 相邻两项的起跑间隔。
  final Duration step;

  /// 延迟封顶步数（第 N 项起不再更晚）。
  final int maxStaggerSteps;

  /// 上浮距离（px）。
  final double distance;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;

    final delay = step * index.clamp(0, maxStaggerSteps);
    final total = MotionDurations.slow + delay;
    final begin = delay.inMicroseconds / total.inMicroseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(begin, 1, curve: MotionCurves.accordion),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, distance * (1 - t)),
          child: Transform.scale(scale: 0.97 + 0.03 * t, child: child),
        ),
      ),
      child: child,
    );
  }
}
