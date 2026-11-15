// Monster Word — 首页「星夜航程」视觉原子组件（2026-11-15 推倒重设计）。
//
// 从 home_screen part 家族抽出的纯展示组件：星野极光背景、玻璃面板、
// 发光星环、渐变主按钮。全部颜色取自 HomeNightColors 令牌、尺寸走
// AppFontSizes/AppSpacing/AppAlphas/设计语言圆角，静态绘制一次不循环。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/home_night.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';

/// 首页氛围背景：深空画布 + 三向极光 + 确定性星野。
///
/// 艺术方向「星夜航程」：深空墨蓝上，极光青自顶部倾泻、电紫沉在左下、
/// 品红在右缘低语；星野用固定种子散点（无循环动画、无每帧重绘）。
class HomeAmbient extends StatelessWidget {
  const HomeAmbient({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 深空画布：上浅下深的墨蓝垂直渐变
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [HomeNightColors.spaceLift, HomeNightColors.space],
            ),
          ),
        ),
        // 极光青：自顶部中心倾泻而下
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.2, -1.35),
              radius: 1.5,
              colors: [
                HomeNightColors.aurora.withValues(alpha: AppAlphas.o14),
                HomeNightColors.aurora.withValues(alpha: AppAlphas.o0),
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
        // 电紫：沉在左下角的星云
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-1.35, 1.25),
              radius: 1.2,
              colors: [
                HomeNightColors.nebula.withValues(alpha: AppAlphas.o12),
                HomeNightColors.nebula.withValues(alpha: AppAlphas.o0),
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
        // 品红：右缘的一抹暖息
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.45, -0.2),
              radius: 0.9,
              colors: [
                HomeNightColors.ember.withValues(alpha: AppAlphas.o08),
                HomeNightColors.ember.withValues(alpha: AppAlphas.o0),
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
        // 星野（静态、确定性）
        const CustomPaint(painter: _StarFieldPainter()),
        child,
      ],
    );
  }
}

/// 确定性星野：固定种子散点，大小与亮度分层，偶有十字星芒。
class _StarFieldPainter extends CustomPainter {
  const _StarFieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final count = math.min(140, (size.width * size.height / 6000).round());
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final bright = rng.nextDouble();
      final radius = bright > 0.92 ? 1.4 : (bright > 0.6 ? 0.9 : 0.5);
      final alpha = 0.12 + bright * 0.38;
      final paint = Paint()..color = HomeNightColors.stardust.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
      // 最亮的几颗带十字星芒
      if (bright > 0.95) {
        final flare = Paint()
          ..color = HomeNightColors.stardust.withValues(alpha: alpha * 0.5)
          ..strokeWidth = 0.6;
        canvas.drawLine(Offset(x - 4, y), Offset(x + 4, y), flare);
        canvas.drawLine(Offset(x, y - 4), Offset(x, y + 4), flare);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter old) => false;
}

/// 玻璃面板：深空半透明底 + 顶部微光渐变 + 发丝描边 + 外发光。
class HomeGlassPanel extends StatelessWidget {
  const HomeGlassPanel({super.key, required this.child, this.padding, this.glow});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// 外发光色（默认极光青低语）；传 null 关闭发光。
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final glowColor = glow ?? HomeNightColors.aurora;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.design.radius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HomeNightColors.panelLift, HomeNightColors.panel],
        ),
        border: Border.all(color: HomeNightColors.hairline),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: AppAlphas.o10),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 主区 eyebrow 小标签：字距拉开的微型标签 + 前导星点。
class HomeEyebrow extends StatelessWidget {
  const HomeEyebrow({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome_rounded, size: 12, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSizes.micro * context.responsive.fontScale,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// 达标徽章：金色对勾玻璃胶囊。
class HomeDoneBadge extends StatelessWidget {
  const HomeDoneBadge({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppAlphas.o12),
        borderRadius: BorderRadius.circular(context.design.radius.sm),
        border: Border.all(color: color.withValues(alpha: AppAlphas.o40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '已达标',
            style: MwTypography.micro.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// 主区统计锚点：大数字 + 小标签（星白/雾蓝）。
class HomeHeroStat extends StatelessWidget {
  const HomeHeroStat({super.key, required this.value, required this.label, required this.color, this.labelColor});

  final String value;
  final String label;
  final Color color;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: AppFontSizes.heading4 * resp.fontScale,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: -0.5,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: MwTypography.micro.copyWith(color: labelColor ?? HomeNightColors.text3)),
      ],
    );
  }
}

/// 统计列之间的竖分隔线。
class HomeStatDivider extends StatelessWidget {
  const HomeStatDivider({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: color,
    );
  }
}

/// 行内图标底座：极光青 tint 圆角方块 + 发光描边。
class HomeStripIconTile extends StatelessWidget {
  const HomeStripIconTile({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: HomeNightColors.aurora.withValues(alpha: AppAlphas.o10),
        borderRadius: BorderRadius.circular(context.design.radius.md),
        border: Border.all(color: HomeNightColors.aurora.withValues(alpha: AppAlphas.o25)),
      ),
      child: Center(child: child),
    );
  }
}

/// 主按钮：极光青→冰蓝渐变 + 同色外发光 + 按压缩放。
class HomeGlossyCta extends StatelessWidget {
  const HomeGlossyCta({
    super.key,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.gradientEnd,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  /// 渐变另一端；null 时用 backgroundColor 提亮（兼容单色调用）。
  final Color? gradientEnd;

  @override
  Widget build(BuildContext context) {
    final end = gradientEnd ?? Color.lerp(backgroundColor, HomeNightColors.text1, 0.18)!;
    return ScaleDownOnPress(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.design.radius.md),
          gradient: LinearGradient(colors: [backgroundColor, end]),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: AppAlphas.o35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: foregroundColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFontSizes.bodySm,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.15,
                  color: foregroundColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 发光星环：轨道 + 极光渐变弧 + 端点光珠 + 中心计数。
///
/// 环画笔类名保持 `_RingPainter` 以维持 home_greeting_test 的 runtimeType
/// 测试口（progressColor 字段语义不变：达标=金，进行中=极光青）。
class HomeProgressRing extends StatelessWidget {
  const HomeProgressRing({
    super.key,
    required this.size,
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.learned,
    required this.goal,
    this.secondaryColor,
    this.arcEnd,
  });

  final double size;
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final int learned;
  final int goal;
  final Color? secondaryColor;

  /// 弧的渐变另一端；null 时单色弧。
  final Color? arcEnd;

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: MotionDurations.count,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            trackColor: trackColor,
            progressColor: progressColor,
            progress: animated,
            arcEnd: arcEnd,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$learned',
                  style: TextStyle(
                    fontSize: AppFontSizes.displaySm * resp.fontScale,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: HomeNightColors.text1,
                  ),
                ),
                Text(
                  '/ $goal',
                  style: TextStyle(
                    fontSize: AppFontSizes.micro * resp.fontScale,
                    height: 1.3,
                    color: secondaryColor ?? HomeNightColors.text3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.trackColor, required this.progressColor, required this.progress, this.arcEnd});

  final Color trackColor;
  final Color progressColor;
  final double progress;
  final Color? arcEnd;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final inset = stroke / 2 + 2;
    final arcRect = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);
    final center = arcRect.center;
    final radius = arcRect.width / 2;

    // 轨道：星白低语环
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawArc(arcRect, 0, 2 * math.pi, false, track);

    if (progress > 0) {
      final sweep = 2 * math.pi * progress;
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      if (arcEnd != null) {
        arc.shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          colors: [progressColor, arcEnd!, progressColor],
          stops: const [0.0, 0.5, 1.0],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(arcRect);
      } else {
        arc.color = progressColor;
      }
      // 弧下柔光（发光星环的关键一笔）
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 6
        ..strokeCap = StrokeCap.round
        ..color = progressColor.withValues(alpha: AppAlphas.o18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawArc(arcRect, -math.pi / 2, sweep, false, glow);
      canvas.drawArc(arcRect, -math.pi / 2, sweep, false, arc);

      // 端点光珠：弧终点一颗亮星
      final endAngle = -math.pi / 2 + sweep;
      final tip = Offset(center.dx + radius * math.cos(endAngle), center.dy + radius * math.sin(endAngle));
      final halo = Paint()
        ..color = progressColor.withValues(alpha: AppAlphas.o35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(tip, stroke * 0.9, halo);
      canvas.drawCircle(tip, stroke * 0.45, Paint()..color = HomeNightColors.text1);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor ||
      old.arcEnd != arcEnd;
}

/// 头部玻璃图标按钮：圆角方块 + 发丝描边 + 星白图标。
class HomeHeaderIconButton extends StatelessWidget {
  const HomeHeaderIconButton({super.key, required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.longPress,
      child: ScaleDownOnPress(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.design.radius.md),
            color: HomeNightColors.glass,
            border: Border.all(color: HomeNightColors.hairline),
          ),
          child: Icon(icon, color: HomeNightColors.text2, size: 22),
        ),
      ),
    );
  }
}
