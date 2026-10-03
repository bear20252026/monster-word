// RollingNumber：数字滚动组件（蓝图 W3「数字的戏剧」）。
//
// value 变化时从「组件内记录的旧值」tween 到新值（300ms = MotionDurations.slow
// 语义，Curves.easeOutCubic），用于金币余额/连击数等高频变动的计数展示。
// 零新依赖：TweenAnimationBuilder 为框架自带；整数插值保证中间帧不出现小数
// （金币语义）。
import 'package:flutter/material.dart';

import 'package:word_app/tokens/motion_tokens.dart';

class RollingNumber extends StatefulWidget {
  const RollingNumber({super.key, required this.value, this.style, this.duration = MotionDurations.slow});

  /// 目标值（State 内记录旧值做 tween 起点）。
  final int value;

  final TextStyle? style;

  /// 滚动时长（默认 MotionDurations.slow）。
  final Duration duration;

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber> {
  /// 上一帧展示值（tween 起点；didUpdateWidget 更新）。
  late int _displayed = widget.value;

  @override
  void didUpdateWidget(covariant RollingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _displayed = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      key: ValueKey('$_displayed-${widget.value}'),
      tween: IntTween(begin: _displayed, end: widget.value),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      onEnd: () => _displayed = widget.value,
      builder: (context, animated, _) => Text('$animated', style: widget.style),
    );
  }
}
