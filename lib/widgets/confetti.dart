// Confetti：彩带/礼花庆祝效果，粒子从顶部飘落并旋转
// 颜色/密度/速度/角度均可自定义
// 适用于：学习完成、签到成功、测验满分、升级庆祝、成就达成
import 'dart:math' as math;
import 'package:flutter/material.dart';

class ConfettiParticle {
  Offset position;
  Offset velocity;
  double rotation;
  double rotationSpeed;
  Color color;
  double size;
  double opacity;
  ConfettiShape shape;

  ConfettiParticle({
    required this.position,
    required this.velocity,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.size,
    required this.opacity,
    required this.shape,
  });
}

enum ConfettiShape {
  rectangle,
  circle,
  triangle,
  star,
  strip,
}

enum ConfettiDirection {
  down,       // 向下落
  up,         // 向上喷
  left,       // 向左
  right,      // 向右
  explosion,  // 爆炸式
  shower,     // 淋浴式
}

/// 彩带控制器（触发式，可手动播放）
class ConfettiController extends ChangeNotifier {
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  void play() {
    _isPlaying = true;
    notifyListeners();
  }

  void stop() {
    _isPlaying = false;
    notifyListeners();
  }

  void reset() {
    _isPlaying = false;
    notifyListeners();
  }
}

/// 彩带庆祝效果组件
class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final ConfettiController? controller;
  final int particleCount;
  final List<Color> colors;
  final ConfettiDirection direction;
  final Duration duration;
  final double gravity;
  final bool autoPlay;
  final VoidCallback? onComplete;
  final double spawnRate;

  const ConfettiOverlay({
    super.key,
    required this.child,
    this.controller,
    this.particleCount = 50,
    this.colors = const [
      Color(0xFFFF6B6B),
      Color(0xFFFFD93D),
      Color(0xFF6BCB77),
      Color(0xFF4D96FF),
      Color(0xFFC77DFF),
      Color(0xFFFF922B),
    ],
    this.direction = ConfettiDirection.down,
    this.duration = const Duration(seconds: 3),
    this.gravity = 200,
    this.autoPlay = false,
    this.onComplete,
    this.spawnRate = 0.05,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _controller.addListener(_updateParticles);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _stop();
      }
    });

    widget.controller?.addListener(_onControllerChanged);

    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (widget.controller?.isPlaying == true) {
      _start();
    } else {
      _stop();
    }
  }

  void _start() {
    if (_isPlaying) return;
    setState(() {
      _isPlaying = true;
      _particles.clear();
      _initParticles();
    });
    _controller.forward(from: 0);
  }

  void _stop() {
    if (!_isPlaying) return;
    setState(() {
      _isPlaying = false;
      _particles.clear();
    });
    _controller.reset();
    widget.onComplete?.call();
  }

  void _initParticles() {
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(_createParticle());
    }
  }

  ConfettiParticle _createParticle() {
    final colors = widget.colors;
    final shapes = ConfettiShape.values;

    // 根据方向生成不同的初始速度和位置
    Offset position;
    Offset velocity;

    switch (widget.direction) {
      case ConfettiDirection.down:
        position = Offset(
          _random.nextDouble() * 400 - 50,
          -20 - _random.nextDouble() * 100,
        );
        velocity = Offset(
          (_random.nextDouble() - 0.5) * 200,
          100 + _random.nextDouble() * 200,
        );
        break;
      case ConfettiDirection.up:
        position = Offset(
          _random.nextDouble() * 400 - 50,
          600 + _random.nextDouble() * 100,
        );
        velocity = Offset(
          (_random.nextDouble() - 0.5) * 200,
          -(100 + _random.nextDouble() * 200),
        );
        break;
      case ConfettiDirection.explosion:
        position = const Offset(175, 300);
        final angle = _random.nextDouble() * 2 * math.pi;
        final speed = 150 + _random.nextDouble() * 250;
        velocity = Offset(
          math.cos(angle) * speed,
          math.sin(angle) * speed,
        );
        break;
      case ConfettiDirection.shower:
        position = Offset(
          _random.nextDouble() * 400,
          -20,
        );
        velocity = Offset(
          (_random.nextDouble() - 0.5) * 50,
          150 + _random.nextDouble() * 150,
        );
        break;
      default:
        position = Offset(_random.nextDouble() * 400, -20);
        velocity = Offset(
          (_random.nextDouble() - 0.5) * 200,
          100 + _random.nextDouble() * 200,
        );
    }

    return ConfettiParticle(
      position: position,
      velocity: velocity,
      rotation: _random.nextDouble() * 2 * math.pi,
      rotationSpeed: (_random.nextDouble() - 0.5) * 8,
      color: colors[_random.nextInt(colors.length)],
      size: 6 + _random.nextDouble() * 8,
      opacity: 0.8 + _random.nextDouble() * 0.2,
      shape: shapes[_random.nextInt(shapes.length)],
    );
  }

  void _updateParticles() {
    if (!_isPlaying) return;

    final dt = 1 / 60; // 假设 60fps
    setState(() {
      for (final p in _particles) {
        // 更新位置
        p.position = Offset(
          p.position.dx + p.velocity.dx * dt,
          p.position.dy + p.velocity.dy * dt,
        );

        // 应用重力
        p.velocity = Offset(
          p.velocity.dx,
          p.velocity.dy + widget.gravity * dt,
        );

        // 更新旋转
        p.rotation += p.rotationSpeed * dt;

        // 更新透明度（逐渐消失）
        if (_controller.value > 0.7) {
          p.opacity = math.max(0, p.opacity - dt * 3);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isPlaying)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ConfettiPainter(particles: _particles),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.opacity <= 0) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.position.dx, p.position.dy);
      canvas.rotate(p.rotation);

      switch (p.shape) {
        case ConfettiShape.rectangle:
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
            paint,
          );
          break;
        case ConfettiShape.circle:
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
          break;
        case ConfettiShape.triangle:
          final path = Path()
            ..moveTo(0, -p.size / 2)
            ..lineTo(-p.size / 2, p.size / 2)
            ..lineTo(p.size / 2, p.size / 2)
            ..close();
          canvas.drawPath(path, paint);
          break;
        case ConfettiShape.star:
          _drawStar(canvas, paint, p.size / 2);
          break;
        case ConfettiShape.strip:
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size * 0.3, height: p.size * 2),
            paint,
          );
          break;
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double radius) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + i * 4 * math.pi / 5;
      final x = radius * math.cos(angle);
      final y = radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

/// 简化的彩带触发器（只需一行代码即可触发）
class ConfettiPlayer {
  static ConfettiController? _controller;

  static ConfettiController getController() {
    _controller ??= ConfettiController();
    return _controller!;
  }

  static void play() {
    getController().play();
  }

  static void stop() {
    getController().stop();
  }

  static Widget wrap({
    required Widget child,
    int particleCount = 50,
    List<Color>? colors,
    ConfettiDirection direction = ConfettiDirection.down,
    Duration duration = const Duration(seconds: 3),
  }) {
    return ConfettiOverlay(
      controller: getController(),
      particleCount: particleCount,
      colors: colors ?? const [
        Color(0xFFFF6B6B),
        Color(0xFFFFD93D),
        Color(0xFF6BCB77),
        Color(0xFF4D96FF),
        Color(0xFFC77DFF),
        Color(0xFFFF922B),
      ],
      direction: direction,
      duration: duration,
      child: child,
    );
  }
}
