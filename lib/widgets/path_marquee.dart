// Path Marquee：文字沿路径滚动流动（波浪、圆形、自定义路径）
// 颜色/速度/方向均可自定义
// 适用于：品牌展示、空状态装饰、首页装饰文字、数据展示
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../tokens/design_tokens.dart';

/// 路径类型枚举
enum MarqueePathType {
  sine,      // 正弦波
  circle,    // 圆形
  ellipse,   // 椭圆
  arc,       // 弧形
  figure8,   // 8 字形
  custom,    // 自定义路径
}

/// 滚动方向
enum MarqueeDirection {
  forward,    // 正向
  backward,   // 反向
  alternate,  // 来回
}

/// 路径滚动文字
class PathMarquee extends StatefulWidget {
  final String text;
  final MarqueePathType pathType;
  final MarqueeDirection direction;
  final TextStyle? textStyle;
  final Color? pathColor;
  final double pathWidth;
  final double pathHeight;
  final double speed;          // 滚动速度 (0.1 - 3.0)
  final Duration loopDuration; // 循环周期
  final bool showPath;         // 是否显示路径线
  final bool repeat;           // 是否循环
  final Path Function(Size)? customPathBuilder;

  const PathMarquee({
    super.key,
    required this.text,
    this.pathType = MarqueePathType.sine,
    this.direction = MarqueeDirection.forward,
    this.textStyle,
    this.pathColor,
    this.pathWidth = 300,
    this.pathHeight = 80,
    this.speed = 1.0,
    this.loopDuration = const Duration(seconds: 4),
    this.showPath = false,
    this.repeat = true,
    this.customPathBuilder,
  });

  @override
  State<PathMarquee> createState() => _PathMarqueeState();
}

class _PathMarqueeState extends State<PathMarquee>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _reversed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.loopDuration,
    );

    if (widget.repeat) {
      _controller.repeat();
    } else {
      _controller.forward();
    }

    if (widget.direction == MarqueeDirection.alternate) {
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _reversed = true;
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed && _reversed) {
          _reversed = false;
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Path _buildPath(Size size) {
    if (widget.pathType == MarqueePathType.custom && widget.customPathBuilder != null) {
      return widget.customPathBuilder!(size);
    }

    switch (widget.pathType) {
      case MarqueePathType.sine:
        return _buildSinePath(size);
      case MarqueePathType.circle:
        return _buildCirclePath(size);
      case MarqueePathType.ellipse:
        return _buildEllipsePath(size);
      case MarqueePathType.arc:
        return _buildArcPath(size);
      case MarqueePathType.figure8:
        return _buildFigure8Path(size);
      case MarqueePathType.custom:
        return _buildSinePath(size);
    }
  }

  Path _buildSinePath(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    final midY = height / 2;
    final amplitude = height * 0.3;

    path.moveTo(0, midY);
    for (double x = 0; x <= width; x += 1) {
      final y = midY + amplitude * math.sin((x / width) * 2 * math.pi);
      path.lineTo(x, y);
    }
    return path;
  }

  Path _buildCirclePath(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.35;
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  Path _buildEllipsePath(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rx = size.width * 0.4;
    final ry = size.height * 0.35;
    return Path()..addOval(Rect.fromCenter(center: center, width: rx * 2, height: ry * 2));
  }

  Path _buildArcPath(Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width * 0.45;
    return Path()..addArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.8,
      math.pi * 1.6,
    );
  }

  Path _buildFigure8Path(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final rx = size.width * 0.3;
    final ry = size.height * 0.35;

    // 使用参数方程绘制 8 字形（双纽线）
    for (double t = 0; t <= 2 * math.pi; t += 0.02) {
      final x = center.dx + rx * math.sin(t);
      final y = center.dy + ry * math.sin(t) * math.cos(t);
      if (t == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.pathWidth,
      height: widget.pathHeight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final path = _buildPath(Size(widget.pathWidth, widget.pathHeight));

          return CustomPaint(
            size: Size(widget.pathWidth, widget.pathHeight),
            painter: _PathMarqueePainter(
              text: widget.text,
              path: path,
              progress: _controller.value,
              textStyle: widget.textStyle ?? const TextStyle(fontSize: 16, color: MistralColors.ink),
              pathColor: widget.pathColor,
              showPath: widget.showPath,
              direction: widget.direction,
            ),
          );
        },
      ),
    );
  }
}

class _PathMarqueePainter extends CustomPainter {
  final String text;
  final Path path;
  final double progress;
  final TextStyle textStyle;
  final Color? pathColor;
  final bool showPath;
  final MarqueeDirection direction;

  _PathMarqueePainter({
    required this.text,
    required this.path,
    required this.progress,
    required this.textStyle,
    this.pathColor,
    required this.showPath,
    required this.direction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制路径线
    if (showPath) {
      final pathPaint = Paint()
        ..color = (pathColor ?? MistralColors.grey500).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawPath(path, pathPaint);
    }

    // 计算文字在路径上的位置
    final metrics = path.computeMetrics().first;
    final textLength = metrics.length;
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    // 沿路径偏移量
    final textWidth = textPainter.width;
    final maxOffset = textLength + textWidth;
    double offset;

    switch (direction) {
      case MarqueeDirection.forward:
        offset = -textWidth + progress * maxOffset;
        break;
      case MarqueeDirection.backward:
        offset = textLength - progress * maxOffset;
        break;
      case MarqueeDirection.alternate:
        offset = -textWidth + progress * maxOffset;
        break;
    }

    // 沿路径绘制文字
    _drawTextAlongPath(canvas, metrics, textPainter, offset, textLength);
  }

  void _drawTextAlongPath(
    Canvas canvas,
    ui.PathMetric metrics,
    TextPainter textPainter,
    double startOffset,
    double pathLength,
  ) {
    final text = textPainter.text!.toPlainText();
    final charWidth = textPainter.width / text.length;

    for (int i = 0; i < text.length; i++) {
      final charOffset = startOffset + charWidth * i;

      // 超出路径范围则跳过
      if (charOffset < -charWidth || charOffset > pathLength + charWidth) continue;

      // 对偏移量取模实现循环
      final modOffset = charOffset % pathLength;
      final adjustedOffset = modOffset < 0 ? modOffset + pathLength : modOffset;

      final pos = metrics.getTangentForOffset(adjustedOffset);
      if (pos == null) continue;

      canvas.save();
      canvas.translate(pos.position.dx, pos.position.dy);
      canvas.rotate(pos.angle);
      textPainter.paint(canvas, Offset(-charWidth / 2, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PathMarqueePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.text != text;
}

/// 多行路径滚动文字（适合展示多组信息）
class MultiPathMarquee extends StatelessWidget {
  final List<String> texts;
  final List<Color> colors;
  final MarqueePathType pathType;
  final double height;
  final double speed;

  const MultiPathMarquee({
    super.key,
    required this.texts,
    required this.colors,
    this.pathType = MarqueePathType.sine,
    this.height = 200,
    this.speed = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(texts.length, (i) {
          return PathMarquee(
            text: texts[i],
            pathType: pathType,
            pathHeight: height / texts.length - 8,
            speed: speed * (1 + i * 0.2),
            direction: i % 2 == 0
                ? MarqueeDirection.forward
                : MarqueeDirection.backward,
            textStyle: TextStyle(
              fontSize: 14 + i * 2,
              fontWeight: FontWeight.w600,
              color: colors[i % colors.length],
            ),
            showPath: false,
          );
        }),
      ),
    );
  }
}

/// 圆形路径滚动文字（Logo/品牌名专用）
class CircleMarqueeText extends StatelessWidget {
  final String text;
  final double radius;
  final TextStyle? textStyle;
  final Color? pathColor;
  final double speed;

  const CircleMarqueeText({
    super.key,
    required this.text,
    this.radius = 80,
    this.textStyle,
    this.pathColor,
    this.speed = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return PathMarquee(
      text: '$text   $text   ', // 重复以确保无缝循环
      pathType: MarqueePathType.circle,
      pathWidth: radius * 2,
      pathHeight: radius * 2,
      textStyle: textStyle ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      pathColor: pathColor,
      speed: speed,
    );
  }
}
