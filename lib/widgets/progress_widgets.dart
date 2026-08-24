// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 进度相关控件：翻译自 widget/ 中的进度类
// 文件：CircleProgressBar, VerticalLevelView

import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 圆形进度条（翻译自 CircleProgressBar.dart）
class CircleProgressBar extends StatelessWidget {
  final double progress; // 0.0 ~ 1.0
  final double size;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;
  final Widget? child;
  final bool showPercentage;

  const CircleProgressBar({
    super.key,
    required this.progress,
    this.size = 60,
    this.strokeWidth = 4,
    this.backgroundColor = const Color(0x12000000),
    this.progressColor = Colors.blue,
    this.child,
    this.showPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _CircleProgressPainter(
              progress: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              backgroundColor: backgroundColor,
              progressColor: progressColor,
            ),
          ),
          ?child,
          if (showPercentage && child == null)
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: size * 0.2,
                fontWeight: FontWeight.bold,
                color: progressColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  _CircleProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 背景圆
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // 进度弧
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor;
  }
}

/// 不确定进度的圆形加载指示器
class IndeterminateCircleProgress extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color color;

  const IndeterminateCircleProgress({
    super.key,
    this.size = 40,
    this.strokeWidth = 3,
    this.color = Colors.blue,
  });

  @override
  State<IndeterminateCircleProgress> createState() =>
      _IndeterminateCircleProgressState();
}

class _IndeterminateCircleProgressState
    extends State<IndeterminateCircleProgress>
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
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _IndeterminatePainter(
            progress: _controller.value,
            strokeWidth: widget.strokeWidth,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _IndeterminatePainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;

  _IndeterminatePainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final startAngle = -math.pi / 2 + progress * 2 * math.pi;
    const sweepAngle = math.pi * 1.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_IndeterminatePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
