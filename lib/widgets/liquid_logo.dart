// 液态 Logo 动画：流动渐变 + 弹性变形效果
// 适用于：启动页 Logo、加载动画、品牌展示
import 'dart:math' as math;
import 'package:flutter/material.dart';

class LiquidLogo extends StatefulWidget {
  final double size;
  final Duration duration;
  final List<Color>? colors;
  final Widget? child;
  final bool autoPlay;

  const LiquidLogo({
    super.key,
    this.size = 120,
    this.duration = const Duration(seconds: 3),
    this.colors,
    this.child,
    this.autoPlay = true,
  });

  @override
  State<LiquidLogo> createState() => _LiquidLogoState();
}

class _LiquidLogoState extends State<LiquidLogo>
    with TickerProviderStateMixin {
  late AnimationController _morphController;
  late AnimationController _floatController;
  late Animation<double> _morphAnim;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _morphAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _morphController, curve: Curves.linear),
    );
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    if (widget.autoPlay) {
      _morphController.repeat();
      _floatController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ??
        [
          const Color(0xFF006241),
          const Color(0xFF00754A),
          const Color(0xFF1E3932),
          const Color(0xFFcba258),
        ];

    return AnimatedBuilder(
      animation: Listenable.merge([_morphAnim, _floatAnim]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _LiquidPainter(
              progress: _morphAnim.value,
              colors: colors,
            ),
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(child: widget.child),
            ),
          ),
        );
      },
    );
  }
}

class _LiquidPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _LiquidPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 绘制多层液态渐变圆
    for (int i = 0; i < 3; i++) {
      final phase = progress + (i * math.pi * 2 / 3);
      final dx = math.sin(phase) * radius * 0.15;
      final dy = math.cos(phase * 1.3) * radius * 0.15;
      final blobRadius = radius * (0.7 + 0.1 * math.sin(phase * 2));

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            colors[i % colors.length].withValues(alpha: 0.6 - i * 0.15),
            colors[(i + 1) % colors.length].withValues(alpha: 0.2),
          ],
        ).createShader(Rect.fromCircle(
          center: center + Offset(dx, dy),
          radius: blobRadius,
        ));

      canvas.drawCircle(
        center + Offset(dx, dy),
        blobRadius,
        paint,
      );
    }

    // 主圆
    final mainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors[0].withValues(alpha: 0.9),
          colors[1].withValues(alpha: 0.85),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.65));

    canvas.drawCircle(center, radius * 0.65, mainPaint);

    // 高光
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25);
    canvas.drawCircle(
      center + Offset(-radius * 0.15, -radius * 0.15),
      radius * 0.2,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 简化的液态加载指示器
class LiquidLoadingIndicator extends StatefulWidget {
  final double size;
  final Color color;

  const LiquidLoadingIndicator({
    super.key,
    this.size = 40,
    this.color = const Color(0xFF006241),
  });

  @override
  State<LiquidLoadingIndicator> createState() => _LiquidLoadingIndicatorState();
}

class _LiquidLoadingIndicatorState extends State<LiquidLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _LiquidDropPainter(
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _LiquidDropPainter extends CustomPainter {
  final double progress;
  final Color color;

  _LiquidDropPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final t = progress * 2 * math.pi;

    // 三个跳动的圆点
    for (int i = 0; i < 3; i++) {
      final phase = t + (i * math.pi * 2 / 3);
      final scale = 0.5 + 0.5 * math.sin(phase);
      final y = center.dy + math.sin(phase) * size.height * 0.15;
      final x = center.dx + (i - 1) * size.width * 0.2;

      final paint = Paint()
        ..color = color.withValues(alpha: 0.6 + 0.4 * scale);

      canvas.drawCircle(Offset(x, y), size.width * 0.08 + scale * size.width * 0.04, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidDropPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
