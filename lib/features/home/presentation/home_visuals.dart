// Monster Word — 首页高级感视觉原子组件（2026-11-14 UI 重构）。
//
// 从 home_screen part 家族抽出的纯展示组件：分层氛围背景、主卡装饰原子、
// 条带图标底座。抽成独立公共文件（非 part）既让 part 家族回到行数合规，
// 也让这些可复用视觉基元有单一归属。全部颜色取自 skin 令牌、尺寸走
// AppFontSizes/AppSpacing/AppAlphas，随主题与设计语言切换自动响应。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';

/// 首页氛围背景：奶油纸面 + 单一品牌色顶部微光 + 细粒噪点。
///
/// 2026-11-15 美学收敛：全页只允许一个主色族（墨绿）+ 奶油中性 +
/// 金色仅用于「达成」。背景不再用橙/蓝多向极光（那是上一版混乱的根源），
/// 只留一抹顶部品牌色晕与向纸色的垂直渐隐，层次靠明度而非色相堆叠。
class HomeAmbient extends StatelessWidget {
  const HomeAmbient({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 纯纸面画布（2026-11-15 定稿：去掉渐隐带，纸色即背景，层次靠卡片与留白）
        ColoredBox(color: colors.pageBg),
        // 细粒噪点（静态、确定性，纸面质感）
        CustomPaint(painter: _GrainPainter(color: colors.text1)),
        child,
      ],
    );
  }
}

/// 确定性细粒噪点：固定种子的伪随机散点，低透明度，绘制一次不循环。
class _GrainPainter extends CustomPainter {
  const _GrainPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final paint = Paint()..color = color.withValues(alpha: 0.018);
    // 散点密度随面积自适应，封顶避免大屏过度绘制。
    final count = math.min(220, (size.width * size.height / 2600).round());
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.color != color;
}

/// 主卡 eyebrow 小标签：字距拉开的微型大写感标签。
class HomeEyebrow extends StatelessWidget {
  const HomeEyebrow({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: AppFontSizes.micro * context.responsive.fontScale,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
        color: color,
      ),
    );
  }
}

/// 达标徽章：金色对勾胶囊。
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

/// 主卡统计锚点：大数字 + 小标签。
class HomeHeroStat extends StatelessWidget {
  const HomeHeroStat({super.key, required this.value, required this.label, required this.color, this.labelColor});

  final String value;
  final String label;
  final Color color;

  /// 小标签色；null 回退主题三级文字（浅色卡），深色面板传奶油白。
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
        Text(label, style: MwTypography.micro.copyWith(color: labelColor ?? context.skin.colors.text3)),
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

/// 条带共享图标底座：单一墨色 tint 圆角方块 + 主色图标 + 发丝描边。
///
/// 2026-11-15 美学收敛：三个徽章不再各用橙/绿/蓝饱和渐变（色彩角色过多
/// 是混乱根源），统一为同一主色族的浅 tint，靠图标与文案区分语义，
/// 全页色彩节奏只保留「墨绿主色 + 奶油中性 + 金色达成」。
class HomeStripIconTile extends StatelessWidget {
  const HomeStripIconTile({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: AppAlphas.o08),
        borderRadius: BorderRadius.circular(context.design.radius.md),
        border: Border.all(color: colors.accent.withValues(alpha: AppAlphas.o15)),
      ),
      child: Center(child: child),
    );
  }
}

/// 主卡倒置胶囊 CTA：扁平实色（奶油或金）+ 深色前景 + 按压缩放。
///
/// 2026-11-15 美学收敛：深色面板上的高对比按钮用「倒置」而非「光泽」——
/// 奶油底/墨字（未达标）或金底/墨字（达标），去掉渐变与彩色投影，
/// 让对比来自明度反转，保持全页只有墨绿/奶油/金三个色彩角色。
class HomeGlossyCta extends StatelessWidget {
  const HomeGlossyCta({
    super.key,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleDownOnPress(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(context.design.radius.md),
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

/// 环形进度（track + 圆头渐变弧 + 端点光晕），中心显示 已学/目标。
///
/// 2026-11-15 从 home_hero 抽至此处（视觉原子单一归属）。环画笔类名
/// 保持 `_RingPainter` 以维持 home_greeting_test 的 runtimeType 测试口。
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
  });

  final double size;
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final int learned;
  final int goal;

  /// 中心「/ 目标」副文字色；null 时回退主题三级文字（浅色卡），
  /// 深色面板传奶油白以保证对比。
  final Color? secondaryColor;

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
          painter: _RingPainter(trackColor: trackColor, progressColor: progressColor, progress: animated),
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
                    color: progressColor,
                  ),
                ),
                Text(
                  '/ $goal',
                  style: TextStyle(
                    fontSize: AppFontSizes.micro * resp.fontScale,
                    height: 1.3,
                    color: secondaryColor ?? context.skin.colors.text3,
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
  const _RingPainter({required this.trackColor, required this.progressColor, required this.progress});

  final Color trackColor;
  final Color progressColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // 2026-11-15 美学收敛：细弧实色（仪表感），去掉渐变扫光与光晕珠，
    // 只留一枚小端点作「当前进度」标记，克制而精确。
    const stroke = 4.0;
    final inset = stroke / 2 + 1;
    final arcRect = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);
    final center = arcRect.center;
    final radius = arcRect.width / 2;

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
        ..strokeCap = StrokeCap.round
        ..color = progressColor;
      canvas.drawArc(arcRect, -math.pi / 2, sweep, false, arc);

      final endAngle = -math.pi / 2 + sweep;
      final tip = Offset(center.dx + radius * math.cos(endAngle), center.dy + radius * math.sin(endAngle));
      canvas.drawCircle(tip, stroke * 0.9, Paint()..color = progressColor);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.trackColor != trackColor || old.progressColor != progressColor;
}

/// 头部渐变玻璃图标按钮：圆形 + 发丝描边 + 双层细影。
class HomeHeaderIconButton extends StatelessWidget {
  const HomeHeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final ThemeVars colors;
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
            color: colors.cardBg,
            border: Border.all(color: colors.divider),
            boxShadow: const [BoxShadow(color: MwShadows.hairlineShadow, blurRadius: 0.5)],
          ),
          child: Icon(icon, color: colors.text2, size: 22),
        ),
      ),
    );
  }
}
