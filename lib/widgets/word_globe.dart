// Word Globe：3D 旋转星球 + 连接线 + 闪烁光点
// 颜色可自定义（默认绿色主题），支持自动旋转和触摸交互
// 适用于：单词起源展示、关于页背景、启动页装饰、全球用户分布
import 'dart:math' as math;

import 'package:flutter/material.dart';

class GlobePoint {
  final double lat; // 纬度 (-90 to 90)
  final double lon; // 经度 (-180 to 180)
  final double size;
  final Color color;
  final String? label;

  const GlobePoint({
    required this.lat,
    required this.lon,
    this.size = 4,
    this.color = const Color(0xFF006241),
    this.label,
  });
}

class GlobeArc {
  final double fromLat;
  final double fromLon;
  final double toLat;
  final double toLon;
  final Color color;
  final double width;

  const GlobeArc({
    required this.fromLat,
    required this.fromLon,
    required this.toLat,
    required this.toLon,
    this.color = const Color(0xFF006241),
    this.width = 1.5,
  });
}

class WordGlobe extends StatefulWidget {
  final double size;
  final Color? globeColor;
  final Color? pointColor;
  final Color? arcColor;
  final Color? atmosphereColor;
  final List<GlobePoint> points;
  final List<GlobeArc> arcs;
  final bool autoRotate;
  final double rotationSpeed;
  final bool enableZoom;
  final bool enableRotation;
  final VoidCallback? onTap;

  const WordGlobe({
    super.key,
    this.size = 200,
    this.globeColor,
    this.pointColor,
    this.arcColor,
    this.atmosphereColor,
    this.points = const [],
    this.arcs = const [],
    this.autoRotate = true,
    this.rotationSpeed = 0.3,
    this.enableZoom = true,
    this.enableRotation = true,
    this.onTap,
  });

  @override
  State<WordGlobe> createState() => _WordGlobeState();
}

class _WordGlobeState extends State<WordGlobe> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  double _rotationY = 0;
  double _rotationX = 0.3;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 20));

    if (widget.autoRotate) {
      _rotationController.addListener(() {
        setState(() {
          _rotationY += widget.rotationSpeed;
        });
      });
      _rotationController.repeat();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  // 注意：GestureDetector 不能同时注册 onPan* 和 onScale*
  // （debug 模式会抛 Incorrect GestureDetector arguments），
  // 因此拖拽旋转和双指缩放统一走 Scale 手势：用焦点位移算旋转，scale 倍率算缩放。
  Offset _lastFocalPoint = Offset.zero;

  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.enableRotation && !widget.enableZoom) return;
    setState(() {
      if (widget.enableRotation) {
        final delta = details.localFocalPoint - _lastFocalPoint;
        _rotationY += delta.dx * 0.5;
        _rotationX += delta.dy * 0.3;
        _rotationX = _rotationX.clamp(-math.pi / 2, math.pi / 2);
      }
      if (widget.enableZoom && details.scale != 1.0) {
        _scale = (_scale * details.scale).clamp(0.5, 2.0);
      }
      _lastFocalPoint = details.localFocalPoint;
    });
  }

  @override
  Widget build(BuildContext context) {
    final globeColor = widget.globeColor ?? const Color(0xFF1E3932);
    final pointColor = widget.pointColor ?? const Color(0xFF006241);
    final arcColor = widget.arcColor ?? const Color(0xFFcba258);
    final atmosphereColor = widget.atmosphereColor ?? const Color(0xFF00754A);

    return GestureDetector(
      onTap: widget.onTap,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _rotationController,
          builder: (context, _) {
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _GlobePainter(
                rotationY: _rotationY,
                rotationX: _rotationX,
                scale: _scale,
                globeColor: globeColor,
                pointColor: pointColor,
                arcColor: arcColor,
                atmosphereColor: atmosphereColor,
                points: widget.points,
                arcs: widget.arcs,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GlobePainter extends CustomPainter {
  final double rotationY;
  final double rotationX;
  final double scale;
  final Color globeColor;
  final Color pointColor;
  final Color arcColor;
  final Color atmosphereColor;
  final List<GlobePoint> points;
  final List<GlobeArc> arcs;

  _GlobePainter({
    required this.rotationY,
    required this.rotationX,
    required this.scale,
    required this.globeColor,
    required this.pointColor,
    required this.arcColor,
    required this.atmosphereColor,
    required this.points,
    required this.arcs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.8 * scale;

    // 大气层光晕
    final atmospherePaint = Paint()
      ..shader = RadialGradient(
        colors: [atmosphereColor.withValues(alpha: 0.15), atmosphereColor.withValues(alpha: 0.05), Colors.transparent],
        stops: const [0.7, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2));
    canvas.drawCircle(center, radius * 1.2, atmospherePaint);

    // 星球主体
    final globePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [globeColor.withValues(alpha: 0.9), globeColor, globeColor.withValues(alpha: 0.7)],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, globePaint);

    // 经纬线网格
    _drawGrid(canvas, center, radius);

    // 绘制连接线
    for (final arc in arcs) {
      _drawArc(canvas, center, radius, arc);
    }

    // 绘制点
    for (final point in points) {
      _drawPoint(canvas, center, radius, point);
    }

    // 高光
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: [Colors.white.withValues(alpha: 0.25), Colors.white.withValues(alpha: 0)],
        stops: const [0.0, 0.5],
      ).createShader(Rect.fromCircle(center: center + Offset(-radius * 0.25, -radius * 0.25), radius: radius * 0.5));
    canvas.drawCircle(center + Offset(-radius * 0.25, -radius * 0.25), radius * 0.5, highlightPaint);
  }

  void _drawGrid(Canvas canvas, Offset center, double radius) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // 纬线
    for (int i = -2; i <= 2; i++) {
      final lat = i * 30 * math.pi / 180;
      final y = center.dy + radius * math.sin(lat);
      final r = radius * math.cos(lat);
      canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, y), width: r * 2, height: r * 0.3), gridPaint);
    }

    // 经线（部分可见）
    for (int i = 0; i < 8; i++) {
      final lon = i * math.pi / 4 + rotationY * math.pi / 180;
      final cosLon = math.cos(lon);
      if (cosLon < 0) continue; // 只画面向观察者的经线

      final path = Path();
      for (double lat = -math.pi / 2; lat <= math.pi / 2; lat += 0.1) {
        final x = center.dx + radius * math.cos(lat) * math.sin(lon);
        final y = center.dy + radius * math.sin(lat) * math.cos(rotationX);
        if (lat == -math.pi / 2) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, gridPaint);
    }
  }

  void _drawPoint(Canvas canvas, Offset center, double radius, GlobePoint point) {
    final pos = _latLonToScreen(center, radius, point.lat, point.lon);
    if (pos == null) return; // 点在星球背面

    // 光点闪烁
    final glowPaint = Paint()
      ..color = point.color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(pos, point.size * 2, glowPaint);

    // 核心点
    final pointPaint = Paint()
      ..color = point.color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, point.size, pointPaint);

    // 白色中心
    final corePaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(pos, point.size * 0.4, corePaint);
  }

  void _drawArc(Canvas canvas, Offset center, double radius, GlobeArc arc) {
    final from = _latLonToScreen(center, radius, arc.fromLat, arc.fromLon);
    final to = _latLonToScreen(center, radius, arc.toLat, arc.toLon);
    if (from == null || to == null) return;

    // 绘制弧线（使用二次贝塞尔曲线，中点抬高）
    final mid = Offset(
      (from.dx + to.dx) / 2,
      (from.dy + to.dy) / 2 - 30, // 弧线凸起高度
    );

    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy);

    final arcPaint = Paint()
      ..shader = LinearGradient(
        colors: [arc.color.withValues(alpha: 0.2), arc.color.withValues(alpha: 0.8), arc.color.withValues(alpha: 0.2)],
      ).createShader(Rect.fromPoints(from, to))
      ..style = PaintingStyle.stroke
      ..strokeWidth = arc.width;

    canvas.drawPath(path, arcPaint);
  }

  Offset? _latLonToScreen(Offset center, double radius, double lat, double lon) {
    final latRad = lat * math.pi / 180;
    final lonRad = (lon + rotationY) * math.pi / 180;

    // 3D 旋转
    final x3d = math.cos(latRad) * math.sin(lonRad);
    final y3d = math.sin(latRad);
    final z3d = math.cos(latRad) * math.cos(lonRad);

    // 只在 z > 0（面向观察者）时绘制
    if (z3d < 0) return null;

    final x = center.dx + radius * x3d;
    final y = center.dy - radius * y3d * math.cos(rotationX);

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) =>
      oldDelegate.rotationY != rotationY || oldDelegate.rotationX != rotationX || oldDelegate.scale != scale;
}

/// 预设数据：单词起源地
class WordOriginData {
  static const List<GlobePoint> origins = [
    GlobePoint(lat: 41.9, lon: 12.5, label: 'Latin', color: Color(0xFFcba258), size: 6), // 罗马 - 拉丁语
    GlobePoint(lat: 37.98, lon: 23.72, label: 'Greek', color: Color(0xFF00754A), size: 6), // 雅典 - 希腊语
    GlobePoint(lat: 48.85, lon: 2.35, label: 'French', color: Color(0xFF4D96FF), size: 5), // 巴黎 - 法语
    GlobePoint(lat: 51.5, lon: -0.12, label: 'English', color: Color(0xFF006241), size: 5), // 伦敦 - 英语
    GlobePoint(lat: 52.5, lon: 13.4, label: 'German', color: Color(0xFF6BCB77), size: 4), // 柏林 - 德语
    GlobePoint(lat: 36.7, lon: 3.0, label: 'Arabic', color: Color(0xFFFF6B6B), size: 4), // 阿尔及尔 - 阿拉伯语
  ];

  static const List<GlobeArc> connections = [
    GlobeArc(fromLat: 41.9, fromLon: 12.5, toLat: 51.5, toLon: -0.12, color: Color(0xFFcba258)), // 罗马→伦敦
    GlobeArc(fromLat: 37.98, fromLon: 23.72, toLat: 41.9, toLon: 12.5, color: Color(0xFF00754A)), // 雅典→罗马
    GlobeArc(fromLat: 41.9, fromLon: 12.5, toLat: 48.85, toLon: 2.35, color: Color(0xFF4D96FF)), // 罗马→巴黎
    GlobeArc(fromLat: 48.85, fromLon: 2.35, toLat: 51.5, toLon: -0.12, color: Color(0xFF006241)), // 巴黎→伦敦
  ];
}
