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
  /// 下一次 tween 的起点。
  late int _from = widget.value;

  /// 当前实际显示值（build 内跟踪，只作下一次 tween 起点，不触发重建）。
  late int _shown = widget.value;

  @override
  void didUpdateWidget(covariant RollingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      // 动画中途来新值：从「正在显示的值」接着滚，而不是跳回旧目标值。
      _from = _shown;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      key: ValueKey('$_from-${widget.value}'),
      tween: IntTween(begin: _from, end: widget.value),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      onEnd: () => _from = widget.value,
      builder: (context, animated, _) {
        _shown = animated;
        return Text('$animated', style: widget.style);
      },
    );
  }
}
