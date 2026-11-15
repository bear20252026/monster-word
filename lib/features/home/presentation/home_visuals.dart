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
import 'package:word_app/widgets/scale_down_on_press.dart';

/// 首页分层氛围背景：奶油画布 + 顶部品牌色极光 + 细粒噪点。
///
/// 高级感来自「克制的层次」而非满屏特效：极光只用主题 accent 的低透明度
/// 径向渐变（亮色是奶油上的一抹品牌绿晕，暗色是墨绿上的微光），噪点用
/// 确定性伪随机散点（无循环动画、无每帧重绘），整体静态绘制一次。
class HomeAmbient extends StatelessWidget {
  const HomeAmbient({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 底层画布
        ColoredBox(color: colors.pageBg),
        // 顶部极光：品牌色自顶部中心向下淡出
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -1.15),
              radius: 1.25,
              colors: [
                colors.accent.withValues(alpha: AppAlphas.o12),
                colors.accent.withValues(alpha: AppAlphas.o05),
                colors.accent.withValues(alpha: AppAlphas.o0),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        // 右下角冷调微光（teal 语义色，与顶部暖极光形成对角层次）
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.3, 1.2),
              radius: 1.1,
              colors: [
                colors.teal.withValues(alpha: AppAlphas.o08),
                colors.teal.withValues(alpha: AppAlphas.o0),
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
        // 细粒噪点（静态、确定性）
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
      decoration: ShapeDecoration(
        color: color.withValues(alpha: AppAlphas.o12),
        shape: StadiumBorder(
          side: BorderSide(color: color.withValues(alpha: AppAlphas.o40)),
        ),
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
  const HomeHeroStat({super.key, required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

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
        Text(label, style: MwTypography.micro.copyWith(color: context.skin.colors.text3)),
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

/// 条带共享图标底座：渐变圆角方块 + 发丝描边（统一三条带的高级质感）。
class HomeStripIconTile extends StatelessWidget {
  const HomeStripIconTile({super.key, required this.gradient, required this.child});

  final Gradient gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(context.design.radius.sm),
        border: Border.all(color: context.skin.colors.accent.withValues(alpha: AppAlphas.o18)),
      ),
      child: Center(child: child),
    );
  }
}

/// 主卡光泽胶囊 CTA：顶部高光渐变 + 柔和投影 + 按压缩放。
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
    final highlight = Color.lerp(backgroundColor, AppColors.white100, 0.18)!;
    return ScaleDownOnPress(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [highlight, backgroundColor],
          ),
          shape: const StadiumBorder(),
          shadows: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: AppAlphas.o35),
              blurRadius: 16,
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
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.cardBg, Color.lerp(colors.cardBg, colors.accent, 0.06)!],
            ),
            border: Border.all(color: colors.divider),
            boxShadow: const [
              BoxShadow(color: MwShadows.hairlineShadow, blurRadius: 0.5),
              BoxShadow(color: MwShadows.liftShadow, blurRadius: 1.0, offset: Offset(0, 1)),
            ],
          ),
          child: Icon(icon, color: colors.accent, size: 22),
        ),
      ),
    );
  }
}
