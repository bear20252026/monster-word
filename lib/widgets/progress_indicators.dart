// 由 Claude 团队生成 | Monster Word App

// 由 Claude 团队生成 | 移植自 v3.2 widget/CircleProgressBar.java, DotIndicator.java, SquareIndicator.java, CircleIndicator.java, PageNumView.java
// 进度条与指示器组件集合
import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import 'animations.dart';

// ─────────────────────────────────────────────────────────────
// CircleProgressBar — 圆形进度条（移植自 CircleProgressBar.java）
// ─────────────────────────────────────────────────────────────
class CircleProgressBar extends StatefulWidget {
  final double progress; // 0.0 ~ 1.0
  final double size;
  final double strokeWidth;
  final Color? backgroundColor;
  final Color? progressColor;
  final Widget? child;
  final bool indeterminate;

  const CircleProgressBar({
    super.key,
    this.progress = 0.0,
    this.size = 48,
    this.strokeWidth = 4,
    this.backgroundColor,
    this.progressColor,
    this.child,
    this.indeterminate = false,
  });

  @override
  State<CircleProgressBar> createState() => _CircleProgressBarState();
}

class _CircleProgressBarState extends State<CircleProgressBar> with TickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.indeterminate) {
      _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    }
  }

  @override
  void didUpdateWidget(CircleProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.indeterminate && _controller == null) {
      _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    } else if (!widget.indeterminate && _controller != null) {
      _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final bgColor = widget.backgroundColor ?? skin.colors.divider;
    final pColor = widget.progressColor ?? skin.colors.accent;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: widget.indeterminate
          ? AnimatedBuilder(
              animation: _controller!,
              builder: (context, child) {
                return CustomPaint(
                  painter: _IndeterminateCirclePainter(
                    color: pColor,
                    strokeWidth: widget.strokeWidth,
                    rotationAngle: _controller!.value * 2 * 3.14159,
                  ),
                  child: widget.child != null ? Center(child: widget.child) : null,
                );
              },
            )
          : CustomPaint(
              painter: _CircleProgressPainter(
                progress: widget.progress.clamp(0.0, 1.0),
                backgroundColor: bgColor,
                progressColor: pColor,
                strokeWidth: widget.strokeWidth,
              ),
              child: widget.child != null ? Center(child: widget.child) : null,
            ),
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width < size.height ? size.width : size.height) / 2 - strokeWidth;

    // 背景圆
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // 进度弧
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = progress * 360;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -90 * 3.14159 / 180,
      sweepAngle * 3.14159 / 180,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircleProgressPainter old) =>
      progress != old.progress || backgroundColor != old.backgroundColor || progressColor != old.progressColor;
}

class _IndeterminateCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double rotationAngle;

  _IndeterminateCirclePainter({required this.color, required this.strokeWidth, required this.rotationAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width < size.height ? size.width : size.height) / 2 - strokeWidth;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 0, 90 * 3.14159 / 180, false, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IndeterminateCirclePainter old) => rotationAngle != old.rotationAngle;
}

// ─────────────────────────────────────────────────────────────
// DotIndicator — 圆点指示器（移植自 DotIndicator.java）
// ─────────────────────────────────────────────────────────────
class DotIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final double dotRadius;
  final double gap;
  final Color? normalColor;
  final Color? activeColor;

  const DotIndicator({
    super.key,
    required this.count,
    this.currentIndex = 0,
    this.dotRadius = 4,
    this.gap = 8,
    this.normalColor,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final nColor = normalColor ?? skin.colors.text3.withAlpha(50);
    final aColor = activeColor ?? skin.colors.accent;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == currentIndex;
        return Container(
          margin: EdgeInsets.symmetric(horizontal: gap / 2),
          width: isActive ? dotRadius * 2 : dotRadius * 2,
          height: isActive ? dotRadius * 2 : dotRadius * 2,
          decoration: BoxDecoration(shape: BoxShape.circle, color: i <= currentIndex ? aColor : nColor),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SquareIndicator — 方形指示器（移植自 SquareIndicator.java）
// ─────────────────────────────────────────────────────────────
class SquareIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final double normalSize;
  final double selectedSize;
  final double gap;
  final Color? normalColor;
  final Color? selectedColor;

  const SquareIndicator({
    super.key,
    required this.count,
    this.currentIndex = 0,
    this.normalSize = 4,
    this.selectedSize = 6,
    this.gap = 6,
    this.normalColor,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final nColor = normalColor ?? skin.colors.text3.withAlpha(140);
    final sColor = selectedColor ?? Colors.white.withAlpha(222);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isSelected = i == currentIndex;
        final size = isSelected ? selectedSize : normalSize;
        return Container(
          margin: EdgeInsets.symmetric(horizontal: gap / 2),
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? sColor : nColor),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CircleIndicator — 带通过状态的圆圈指示器（移植自 CircleIndicator.java）
// ─────────────────────────────────────────────────────────────
class CircleIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final List<bool>? results; // true=passed, false=unpassed
  final double radius;
  final double gap;
  final Color? passedColor;
  final Color? unpassedColor;
  final Color? currentColor;

  const CircleIndicator({
    super.key,
    required this.count,
    this.currentIndex = 0,
    this.results,
    this.radius = 4,
    this.gap = 6,
    this.passedColor,
    this.unpassedColor,
    this.currentColor,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final pColor = passedColor ?? skin.colors.text3.withAlpha(100);
    final uColor = unpassedColor ?? skin.colors.text3.withAlpha(30);
    final cColor = currentColor ?? skin.colors.text3.withAlpha(100);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isCurrent = i == currentIndex;
        final isPassed = results != null && i < results!.length && results![i];
        Color color;
        if (isPassed) {
          color = pColor;
        } else if (isCurrent) {
          color = cColor;
        } else {
          color = uColor;
        }
        final r = isCurrent ? radius * 1.5 : radius;
        return Container(
          margin: EdgeInsets.symmetric(horizontal: gap / 2),
          width: r * 2,
          height: r * 2,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PageNumView — 页码滑动指示器（移植自 PageNumView.java）
// ─────────────────────────────────────────────────────────────
class PageNumIndicator extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final double height;
  final Color? backgroundColor;
  final Color? cursorColor;

  const PageNumIndicator({
    super.key,
    required this.totalPages,
    this.currentPage = 0,
    this.height = 3,
    this.backgroundColor,
    this.cursorColor,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final bgColor = backgroundColor ?? skin.colors.divider;
    final cColor = cursorColor ?? skin.colors.accent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cursorWidth = totalPages > 0 ? constraints.maxWidth / totalPages : 0.0;
        return Container(
          height: height,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(height / 2)),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: standardCurve,
                left: currentPage * cursorWidth,
                width: cursorWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(color: cColor, borderRadius: BorderRadius.circular(height / 2)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
