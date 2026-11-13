// P2-8（架构审计 2026-11-12）：演出共享数学核心单测。
// 锚定二次贝塞尔端点/中点/对称性与粒子 dt 积分恒等/重力/旋转/淡出边界。
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/utils/celebration_math.dart';

void main() {
  group('quadraticBezier', () {
    const a = Offset(0, 0);
    const b = Offset(50, -100);
    const c = Offset(100, 0);

    test('t=0 返回起点', () {
      expect(quadraticBezier(a, b, c, 0), a);
    });

    test('t=1 返回终点', () {
      expect(quadraticBezier(a, b, c, 1), c);
    });

    test('t=0.5 为中点公式 (a+2b+c)/4', () {
      final mid = quadraticBezier(a, b, c, 0.5);
      expect(mid.dx, closeTo((a.dx + 2 * b.dx + c.dx) / 4, 1e-9));
      expect(mid.dy, closeTo((a.dy + 2 * b.dy + c.dy) / 4, 1e-9));
    });

    test('控制点拉高使中点上凸', () {
      final mid = quadraticBezier(a, b, c, 0.5);
      expect(mid.dy, lessThan(0), reason: '控制点在上方，轨迹中点应上凸');
    });

    test('退化直线：控制点在中点时轨迹为直线', () {
      const ctrl = Offset(50, 0);
      final p = quadraticBezier(a, ctrl, c, 0.25);
      expect(p.dx, closeTo(25, 1e-9));
      expect(p.dy, closeTo(0, 1e-9));
    });
  });

  group('stepParticle', () {
    test('dt=0 恒等（位置/速度/旋转/不透明度不变）', () {
      final p = ParticleKinematics(
        position: const Offset(10, 20),
        velocity: const Offset(3, 4),
        rotation: 1,
        opacity: 0.8,
      );
      stepParticle(p, 0, gravity: 200);
      expect(p.position, const Offset(10, 20));
      expect(p.velocity, const Offset(3, 4));
      expect(p.rotation, 1);
      expect(p.opacity, 0.8);
    });

    test('位置按速度·dt 推进', () {
      final p = ParticleKinematics(position: const Offset(0, 0), velocity: const Offset(10, -5));
      stepParticle(p, 0.1, gravity: 0);
      expect(p.position.dx, closeTo(1.0, 1e-9));
      expect(p.position.dy, closeTo(-0.5, 1e-9));
    });

    test('重力累积到纵向速度', () {
      final p = ParticleKinematics(position: Offset.zero, velocity: const Offset(0, 0));
      stepParticle(p, 0.1, gravity: 200);
      expect(p.velocity.dy, closeTo(20, 1e-9));
      expect(p.velocity.dx, 0);
    });

    test('旋转按角速度·dt 增量', () {
      final p = ParticleKinematics(position: Offset.zero, velocity: Offset.zero, rotation: 1, rotationSpeed: 10);
      stepParticle(p, 0.2, gravity: 0);
      expect(p.rotation, closeTo(3, 1e-9));
    });

    test('fading 时不透明度按 dt·3 衰减', () {
      final p = ParticleKinematics(position: Offset.zero, velocity: Offset.zero, opacity: 1);
      stepParticle(p, 0.1, gravity: 0, fading: true);
      expect(p.opacity, closeTo(0.7, 1e-9));
    });

    test('fading 衰减不低于 0', () {
      final p = ParticleKinematics(position: Offset.zero, velocity: Offset.zero, opacity: 0.1);
      stepParticle(p, 1, gravity: 0, fading: true);
      expect(p.opacity, 0);
    });

    test('非 fading 时不透明度不变', () {
      final p = ParticleKinematics(position: Offset.zero, velocity: Offset.zero, opacity: 0.5);
      stepParticle(p, 0.5, gravity: 0, fading: false);
      expect(p.opacity, 0.5);
    });
  });
}
