// Meteors：流星雨/流星划过效果，带有渐变尾迹和闪烁
// 颜色/速度/密度/角度均可自定义
// 适用于：极夜主题背景、启动页、加载页、装饰背景
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../tokens/design_tokens.dart';

class Meteor {
  Offset position;
  Offset velocity;
  double length;
  double width;
  double opacity;
  double life;
  double maxLife;
  Color color;
  Color tailColor;

  Meteor({
    required this.position,
    required this.velocity,
    required this.length,
    required this.width,
    required this.opacity,
    required this.life,
    required this.maxLife,
    required this.color,
    required this.tailColor,
  });
}

/// 流星雨背景
class MeteorShower extends StatefulWidget {
  final Widget? child;
  final int count;
  final List<Color> colors;
  final double speed;
  final double minLength;
  final double maxLength;
  final double width;
  final double spawnRate;
  final bool enableBlink;
  final bool enableStars;
  final double angle;
  final bool autoPlay;

  const MeteorShower({
    super.key,
    this.child,
    this.count = 12,
    this.colors = const [
      Color(0xFF006241),
      Color(0xFF00754A),
      Color(0xFFcba258),
      Color(0xFF4D96FF),
      Color(0xFFC77DFF),
    ],
    this.speed = 1.0,
    this.minLength = 40,
    this.maxLength = 120,
    this.width = 2,
    this.spawnRate = 0.3,
    this.enableBlink = true,
    this.enableStars = true,
    this.angle = math.pi / 4, // 45度角
    this.autoPlay = true,
  });

  @override
  State<MeteorShower> createState() => _MeteorShowerState();
}

class _MeteorShowerState extends State<MeteorShower>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Meteor> _meteors = [];
  final List<_Star> _stars = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    if (widget.autoPlay) {
      _controller.repeat();
    }

    _controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initStars();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initStars() {
    _stars.clear();
    for (int i = 0; i < 60; i++) {
      _stars.add(_Star(
        position: Offset(
          _random.nextDouble() * 400,
          _random.nextDouble() * 600,
        ),
        size: 0.5 + _random.nextDouble() * 2,
        opacity: 0.3 + _random.nextDouble() * 0.7,
        twinkleSpeed: 0.5 + _random.nextDouble() * 2,
        twinklePhase: _random.nextDouble() * 2 * math.pi,
      ));
    }
  }

  void _update() {
    if (!mounted) return;

    setState(() {
      // 生成新流星
      if (_meteors.length < widget.count && _random.nextDouble() < widget.spawnRate) {
        _meteors.add(_createMeteor());
      }

      // 更新流星
      for (int i = _meteors.length - 1; i >= 0; i--) {
        final m = _meteors[i];
        m.position = Offset(
          m.position.dx + m.velocity.dx * widget.speed,
          m.position.dy + m.velocity.dy * widget.speed,
        );
        m.life += 0.016;

        // 淡出
        if (m.life > m.maxLife * 0.6) {
          m.opacity = math.max(0, m.opacity - 0.02);
        }

        // 移除过期流星
        if (m.life >= m.maxLife || m.opacity <= 0) {
          _meteors.removeAt(i);
        }
      }

      // 更新星星闪烁
      if (widget.enableBlink) {
        for (final star in _stars) {
          star.twinklePhase += 0.02 * star.twinkleSpeed;
          star.opacity = 0.3 + 0.35 * (1 + math.sin(star.twinklePhase));
        }
      }
    });
  }

  Meteor _createMeteor() {
    final angle = widget.angle + (_random.nextDouble() - 0.5) * 0.3;
    final speed = 150 + _random.nextDouble() * 200;
    final length = widget.minLength + _random.nextDouble() * (widget.maxLength - widget.minLength);
    final color = widget.colors[_random.nextInt(widget.colors.length)];

    return Meteor(
      position: Offset(
        _random.nextDouble() * 400 - 50,
        -20 - _random.nextDouble() * 100,
      ),
      velocity: Offset(
        math.cos(angle) * speed,
        math.sin(angle) * speed,
      ),
      length: length,
      width: widget.width + _random.nextDouble(),
      opacity: 0.6 + _random.nextDouble() * 0.4,
      life: 0,
      maxLife: 1 + _random.nextDouble() * 2,
      color: color,
      tailColor: color.withValues(alpha: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 背景
        Positioned.fill(
          child: Container(
            decoration: widget.enableStars
                ? BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF0A0F0D),
                        const Color(0xFF1E3932).withValues(alpha: 0.8),
                      ],
                    ),
                  )
                : null,
          ),
        ),
        // 流星和星星
        Positioned.fill(
          child: CustomPaint(
            painter: _MeteorPainter(
              meteors: _meteors,
              stars: widget.enableStars ? _stars : [],
              enableBlink: widget.enableBlink,
            ),
          ),
        ),
        // 内容
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _Star {
  Offset position;
  double size;
  double opacity;
  double twinkleSpeed;
  double twinklePhase;

  _Star({
    required this.position,
    required this.size,
    required this.opacity,
    required this.twinkleSpeed,
    required this.twinklePhase,
  });
}

class _MeteorPainter extends CustomPainter {
  final List<Meteor> meteors;
  final List<_Star> stars;
  final bool enableBlink;

  _MeteorPainter({
    required this.meteors,
    required this.stars,
    required this.enableBlink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制星星
    for (final star in stars) {
      final paint = Paint()
        ..color = AppColors.white100.withValues(alpha: enableBlink ? star.opacity.clamp(0.0, 1.0) : star.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(star.position, star.size, paint);

      // 星星光晕
      final glowPaint = Paint()
        ..color = AppColors.white100.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(star.position, star.size * 2, glowPaint);
    }

    // 绘制流星
    for (final meteor in meteors) {
      if (meteor.opacity <= 0) continue;

      // 流星方向
      final dir = meteor.velocity;
      final angle = math.atan2(dir.dy, dir.dx);

      canvas.save();
      canvas.translate(meteor.position.dx, meteor.position.dy);
      canvas.rotate(angle);

      // 尾迹渐变
      final tailPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            meteor.color.withValues(alpha: meteor.opacity),
            meteor.color.withValues(alpha: meteor.opacity * 0.5),
            meteor.tailColor,
          ],
          stops: const [0.0, 0.3, 1.0],
        ).createShader(Rect.fromLTWH(-meteor.length, -meteor.width / 2, meteor.length, meteor.width));

      // 绘制尾迹
      canvas.drawRect(
        Rect.fromLTWH(-meteor.length, -meteor.width / 2, meteor.length, meteor.width),
        tailPaint,
      );

    // 流星头部（更亮）
      final headPaint = Paint()
        ..color = AppColors.white100.withValues(alpha: meteor.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset.zero, meteor.width * 0.8, headPaint);

      // 头部核心
      final corePaint = Paint()
        ..color = meteor.color.withValues(alpha: meteor.opacity);
      canvas.drawCircle(Offset.zero, meteor.width * 0.5, corePaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _MeteorPainter oldDelegate) => true;
}

/// 简化版流星装饰背景（可叠加在任何页面上）
class MeteorBackground extends StatelessWidget {
  final Widget child;
  final int meteorCount;
  final List<Color> colors;

  const MeteorBackground({
    super.key,
    required this.child,
    this.meteorCount = 8,
    this.colors = const [
      Color(0xFF006241),
      Color(0xFF00754A),
      Color(0xFFcba258),
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MeteorShower(
          count: meteorCount,
          colors: colors,
          enableStars: false,
          child: const SizedBox.expand(),
        ),
        child,
      ],
    );
  }
}
