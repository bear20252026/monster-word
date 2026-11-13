// P2-8（架构审计 2026-11-12）：演出共享数学核心（纯函数）。
//
// 此前 coin_fly_overlay 与签到 painter 各自内联同一套二次贝塞尔多项式，confetti
// 独自维护粒子 dt 积分。本文件收口「可复用的纯数学」，各演出组件委托它，公开 API
// 与驱动层（AnimationController/Ticker/CustomPainter）不变——驱动异构的统一是后续专项。
//
// 纯函数、零 Flutter 依赖（仅 dart:ui 的 Offset），便于单测锚定端点/中点/积分边界。
import 'dart:ui' show Offset;

/// 二次贝塞尔插值：a 起点、b 控制点、c 终点，t∈[0,1]。
///
/// B(t) = (1-t)²·a + 2(1-t)t·b + t²·c。t=0 返回 a，t=1 返回 c。
Offset quadraticBezier(Offset a, Offset b, Offset c, double t) {
  final u = 1 - t;
  return Offset(u * u * a.dx + 2 * u * t * b.dx + t * t * c.dx, u * u * a.dy + 2 * u * t * b.dy + t * t * c.dy);
}

/// 粒子 dt 积分的可变状态（位置/速度/旋转/不透明度）。
class ParticleKinematics {
  ParticleKinematics({
    required this.position,
    required this.velocity,
    this.rotation = 0,
    this.rotationSpeed = 0,
    this.opacity = 1,
  });

  Offset position;
  Offset velocity;
  double rotation;
  double rotationSpeed;
  double opacity;
}

/// 粒子单步 dt 积分：位置 += 速度·dt；速度.y += 重力·dt；旋转 += 角速度·dt；
/// [fading] 为真时不透明度按 dt·3 衰减（不低于 0）。原地修改并返回同一实例。
///
/// 这是 confetti 的物理模型（重力 + 旋转 + 尾段淡出）；签到徽章弹簧/尘粒角速度
/// 是另一套公式，不在此列（不强行合并）。
ParticleKinematics stepParticle(ParticleKinematics p, double dt, {required double gravity, bool fading = false}) {
  p.position = Offset(p.position.dx + p.velocity.dx * dt, p.position.dy + p.velocity.dy * dt);
  p.velocity = Offset(p.velocity.dx, p.velocity.dy + gravity * dt);
  p.rotation += p.rotationSpeed * dt;
  if (fading) {
    final next = p.opacity - dt * 3;
    p.opacity = next < 0 ? 0 : next;
  }
  return p;
}
