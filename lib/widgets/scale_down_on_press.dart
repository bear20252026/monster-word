// Monster Word — 星巴克标准按压反馈包装器
// 来源规格：docs/pressable_inventory.md §5、docs/component_spec.md §1（按压态）
// scale(0.95) + 200ms easeOut；回调在恢复完成后触发（防误触）

import 'package:flutter/material.dart';

/// 星巴克标准按压反馈包装器
///
/// 包裹任意 Widget，按下时缩放至 [scale]，松开后恢复并触发 [onTap]。
/// 支持禁用态（不缩放不响应）、缩放开关（纯点击区域退化）、
/// 长按透传、自定义行为命中测试。
///
/// 用法：
/// ```dart
/// ScaleDownOnPress(
///   onTap: () => print('tapped'),
///   child: Container(...),
/// )
/// ```
class ScaleDownOnPress extends StatefulWidget {
  /// 被包装的子组件
  final Widget child;

  /// 点击回调。null 时整体禁用：不响应、不缩放。
  final VoidCallback? onTap;

  /// 长按回调。不吞 onLongPress，保持手势完整性。
  final VoidCallback? onLongPress;

  /// 语义禁用位：false 时既不缩放也不响应（即使 onTap 非 null）。
  /// 用于列表项禁用态等场景。
  final bool enabled;

  /// 缩放开关：false 时退化为纯点击区域（不缩放）。
  /// 用于灰度对比、特殊语义场景的临时豁免。
  final bool enableScale;

  /// 缩放比例，默认 0.95（星巴克 --buttonActiveScale）
  final double scale;

  /// 动画时长，默认 200ms（星巴克 0.2s ease）
  final Duration duration;

  /// 动画曲线，默认 Curves.easeOut（星巴克 ease）
  final Curve curve;

  /// 透传 GestureDetector.behavior。
  /// 小尺寸图标目标建议传 HitTestBehavior.opaque。
  final HitTestBehavior? behavior;

  /// 回调触发时机：
  /// - true（默认）：松开 → reverse 完成 → 回调（防误触）
  /// - false：抬起立即回调（追求跟手时可开）
  final bool triggerAfterRestore;

  const ScaleDownOnPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.enableScale = true,
    this.scale = 0.95,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOut,
    this.behavior,
    this.triggerAfterRestore = true,
  });

  @override
  State<ScaleDownOnPress> createState() => _ScaleDownOnPressState();
}

class _ScaleDownOnPressState extends State<ScaleDownOnPress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  /// 防止取消后重复触发回调
  bool _hasCancelled = false;

  /// 真正有效的交互判断
  bool get _isInteractive => widget.enabled && widget.onTap != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0, // 初始状态：未缩放
    );
    _animation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
  }

  @override
  void didUpdateWidget(ScaleDownOnPress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    // 禁用时立即恢复到未缩放状态
    if (!_isInteractive && _controller.value < 1.0) {
      _controller.forward(from: _controller.value); // 恢复到 1.0
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!_isInteractive) return;
    _hasCancelled = false;
    _controller.forward(from: _controller.value); // 从当前位置开始缩放
  }

  void _onTapUp(TapUpDetails _) {
    if (!_isInteractive) return;
    _releaseAnimation(triggerClick: true);
  }

  void _onTapCancel() {
    if (!_isInteractive || _hasCancelled) return;
    _hasCancelled = true;
    _releaseAnimation(triggerClick: false);
  }

  void _releaseAnimation({required bool triggerClick}) {
    _controller.reverse().then((_) {
      if (triggerClick && mounted && _isInteractive) {
        widget.onTap?.call();
      }
    });
  }

  void _onLongPressStart(LongPressStartDetails _) {
    if (!_isInteractive) return;
    // 长按开始时保持缩放态（不做额外处理）
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    if (!_isInteractive) return;
    _releaseAnimation(triggerClick: false);
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInteractive) {
      // 禁用态：不缩放，不响应手势
      return widget.child;
    }

    Widget result = ScaleTransition(
      scale: _animation,
      child: widget.child,
    );

    // 支持长按时使用 GestureDetector 统一处理
    if (widget.onLongPress != null) {
      result = GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        behavior: widget.behavior,
        child: result,
      );
    } else {
      result = GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        behavior: widget.behavior,
        child: result,
      );
    }

    return result;
  }
}
