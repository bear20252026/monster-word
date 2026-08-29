// 怪兽尖叫币图标 — CustomPainter 绘制
// 基于用户提供的怪兽形象：圆润可爱的独角怪兽，青绿色皮肤，大眼睛小嘴巴
import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'package:word_app/theme/skin_system.dart';

/// 怪兽尖叫币图标组件
/// 使用 CustomPainter 绘制可爱的独角怪兽头像
class MonsterIcon extends StatelessWidget {
  final double size;
  final Color? bodyColor;
  final Color? bellyColor;
  final bool showCircle;
  final Color? circleColor;

  const MonsterIcon({
    super.key,
    this.size = 40,
    this.bodyColor,
    this.bellyColor,
    this.showCircle = false,
    this.circleColor,
  });

  @override
  Widget build(BuildContext context) {
    final skin = SkinProvider.of(context);
    final body = bodyColor ?? skin.colors.accent; // 默认使用主题强调色（星巴克绿）
    final belly = bellyColor ?? const Color(0xFFB8E6E0); // 浅青色肚皮

    Widget painter = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MonsterPainter(bodyColor: body, bellyColor: belly),
      ),
    );

    if (showCircle) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: circleColor ?? body.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Center(child: painter),
      );
    }

    return painter;
  }
}

class _MonsterPainter extends CustomPainter {
  final Color bodyColor;
  final Color bellyColor;

  _MonsterPainter({required this.bodyColor, required this.bellyColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.85;

    // === 1. 身体（圆润的怪兽主体）===
    final bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;

    // 主体：略椭圆的圆润形状
    final bodyRect = Rect.fromCenter(center: Offset(cx, cy + r * 0.05), width: r * 1.7, height: r * 1.6);
    canvas.drawOval(bodyRect, bodyPaint);

    // === 2. 肚皮（浅色椭圆）===
    final bellyPaint = Paint()
      ..color = bellyColor
      ..style = PaintingStyle.fill;

    final bellyRect = Rect.fromCenter(center: Offset(cx, cy + r * 0.25), width: r * 1.0, height: r * 0.85);
    canvas.drawOval(bellyRect, bellyPaint);

    // === 3. 角（头顶的小角）===
    final hornPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final hornPath = Path();
    hornPath.moveTo(cx - r * 0.15, cy - r * 0.65);
    hornPath.quadraticBezierTo(cx - r * 0.05, cy - r * 1.05, cx + r * 0.05, cy - r * 0.7);
    hornPath.quadraticBezierTo(cx, cy - r * 0.55, cx - r * 0.15, cy - r * 0.65);
    hornPath.close();
    canvas.drawPath(hornPath, hornPaint);

    // 角上的小纹路
    final hornLinePaint = Paint()
      ..color = bodyColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.04
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - r * 0.08, cy - r * 0.75), Offset(cx + r * 0.0, cy - r * 0.68), hornLinePaint);

    // === 4. 眼睛（大眼睛，左眼略大）===
    // 左眼白
    final eyeWhitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.28, cy - r * 0.15), width: r * 0.42, height: r * 0.48),
      eyeWhitePaint,
    );

    // 右眼白
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + r * 0.28, cy - r * 0.15), width: r * 0.38, height: r * 0.44),
      eyeWhitePaint,
    );

    // 瞳孔
    final pupilPaint = Paint()
      ..color = const Color(0xFF2D2D2D)
      ..style = PaintingStyle.fill;

    // 左瞳孔
    canvas.drawCircle(Offset(cx - r * 0.22, cy - r * 0.12), r * 0.13, pupilPaint);
    // 右瞳孔
    canvas.drawCircle(Offset(cx + r * 0.32, cy - r * 0.12), r * 0.12, pupilPaint);

    // 高光
    final highlightPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - r * 0.18, cy - r * 0.2), r * 0.05, highlightPaint);
    canvas.drawCircle(Offset(cx + r * 0.36, cy - r * 0.2), r * 0.045, highlightPaint);

    // === 5. 嘴巴（小微笑）===
    final mouthPaint = Paint()
      ..color = const Color(0xFF2D2D2D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path();
    mouthPath.moveTo(cx - r * 0.12, cy + r * 0.18);
    mouthPath.quadraticBezierTo(cx, cy + r * 0.28, cx + r * 0.12, cy + r * 0.18);
    canvas.drawPath(mouthPath, mouthPaint);

    // === 6. 腮红（小粉红圆点）===
    final blushPaint = Paint()
      ..color = const Color(0xFFFF9999).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - r * 0.45, cy + r * 0.05), r * 0.08, blushPaint);
    canvas.drawCircle(Offset(cx + r * 0.45, cy + r * 0.05), r * 0.08, blushPaint);

    // === 7. 小手（左右各一只）===
    final handPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;

    // 左手
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.75, cy + r * 0.1), width: r * 0.3, height: r * 0.25),
      handPaint,
    );
    // 右手
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + r * 0.75, cy + r * 0.1), width: r * 0.3, height: r * 0.25),
      handPaint,
    );

    // === 8. 脚（两个小脚丫）===
    final footPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.25, cy + r * 0.75), width: r * 0.3, height: r * 0.2),
      footPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + r * 0.25, cy + r * 0.75), width: r * 0.3, height: r * 0.2),
      footPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MonsterPainter oldDelegate) {
    return oldDelegate.bodyColor != bodyColor || oldDelegate.bellyColor != bellyColor;
  }
}

/// 带背景的怪兽圆形头像（用于尖叫币卡片）
class MonsterAvatar extends StatelessWidget {
  final double size;
  final Color? bgColor;

  const MonsterAvatar({super.key, this.size = 52, this.bgColor});

  @override
  Widget build(BuildContext context) {
    final skin = SkinProvider.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bgColor ?? skin.colors.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Center(child: MonsterIcon(size: size * 0.72)),
    );
  }
}
