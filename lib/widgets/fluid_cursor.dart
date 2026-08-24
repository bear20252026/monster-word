// 流体光标：触摸/悬停时产生流体涟漪扩散效果
// 颜色可自定义，支持单点触摸扩散
// 适用于：全局触摸反馈、按钮按下效果、页面交互增强
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 流体光标控制器（全局单例，追踪触摸位置）
class FluidCursorController extends ChangeNotifier {
  Offset? _position;
  bool _isPressed = false;
  final List<_FluidRipple> _ripples = [];

  Offset? get position => _position;
  bool get isPressed => _isPressed;
  List<_FluidRipple> get ripples => _ripples;

  void updatePosition(Offset pos) {
    _position = pos;
    notifyListeners();
  }

  void setPressed(bool pressed) {
    _isPressed = pressed;
    if (pressed && _position != null) {
      _ripples.add(_FluidRipple(
        position: _position!,
        startTime: DateTime.now(),
        color: _rippleColor,
      ));
      if (_ripples.length > 5) _ripples.removeAt(0);
    }
    notifyListeners();
  }

  Color _rippleColor = const Color(0xFF006241);
  void setRippleColor(Color c) => _rippleColor = c;

  void cleanOldRipples() {
    final now = DateTime.now();
    _ripples.removeWhere((r) => now.difference(r.startTime).inMilliseconds > 800);
  }
}

class _FluidRipple {
  final Offset position;
  final DateTime startTime;
  final Color color;

  _FluidRipple({
    required this.position,
    required this.startTime,
    required this.color,
  });
}

/// 流体光标覆盖层（放在最上层，拦截触摸事件）
class FluidCursorOverlay extends StatefulWidget {
  final Widget child;
  final Color rippleColor;
  final double maxRadius;
  final bool enabled;

  const FluidCursorOverlay({
    super.key,
    required this.child,
    this.rippleColor = const Color(0xFF006241),
    this.maxRadius = 80,
    this.enabled = true,
  });

  @override
  State<FluidCursorOverlay> createState() => _FluidCursorOverlayState();
}

class _FluidCursorOverlayState extends State<FluidCursorOverlay>
    with SingleTickerProviderStateMixin {
  late FluidCursorController _controller;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _controller = FluidCursorController()..setRippleColor(widget.rippleColor);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    _animController.addListener(() {
      _controller.cleanOldRipples();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Stack(
      children: [
        widget.child,
        // 流体涟漪层
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                final now = DateTime.now();
                return CustomPaint(
                  painter: _FluidRipplePainter(
                    ripples: _controller.ripples,
                    now: now,
                    maxRadius: widget.maxRadius,
                    color: widget.rippleColor,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FluidRipplePainter extends CustomPainter {
  final List<_FluidRipple> ripples;
  final DateTime now;
  final double maxRadius;
  final Color color;

  _FluidRipplePainter({
    required this.ripples,
    required this.now,
    required this.maxRadius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final ripple in ripples) {
      final elapsed = now.difference(ripple.startTime).inMilliseconds;
      final progress = (elapsed / 800).clamp(0.0, 1.0);

      // 涟漪扩散 + 衰减
      final radius = maxRadius * _easeOutCubic(progress);
      final opacity = (1 - progress) * 0.35;

      // 外层涟漪
      final outerPaint = Paint()
        ..color = color.withValues(alpha: opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (1 - progress);
      canvas.drawCircle(ripple.position, radius, outerPaint);

      // 内层填充
      final innerPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(
          center: ripple.position,
          radius: radius * 0.6,
        ));
      canvas.drawCircle(ripple.position, radius * 0.6, innerPaint);
    }
  }

  double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();

  @override
  bool shouldRepaint(covariant _FluidRipplePainter oldDelegate) => true;
}

/// 流体触摸反馈按钮（按钮按下时产生涟漪）
FluidCursorController? _globalFluidController;

void setGlobalFluidController(FluidCursorController c) {
  _globalFluidController = c;
}

class FluidTouchable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? rippleColor;

  const FluidTouchable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.rippleColor,
  });

  @override
  State<FluidTouchable> createState() => _FluidTouchableState();
}

class _FluidTouchableState extends State<FluidTouchable> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        _globalFluidController?.updatePosition(details.globalPosition);
        _globalFluidController?.setPressed(true);
      },
      onTapUp: (_) => _globalFluidController?.setPressed(false),
      onTapCancel: () => _globalFluidController?.setPressed(false),
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: widget.child,
      ),
    );
  }
}
