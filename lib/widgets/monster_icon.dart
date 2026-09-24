// 怪兽尖叫币图标 — CustomPainter 绘制
// 基于用户提供的怪兽形象：圆润可爱的独角怪兽，青绿色皮肤，大眼睛小嘴巴
import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/effect_palette.dart';

/// 怪兽尖叫币图标组件
/// 使用 CustomPainter 绘制可爱的独角怪兽头像
class MonsterIcon extends StatelessWidget {
  final double size;
  final Color? bodyColor;
  final Color? bellyColor;
  final bool showCircle;
  final Color? circleColor;

  /// 嘴张开程度 0.0（微笑）~1.0（完全张开吃金币），供吞金币庆祝动效驱动。
  final double mouthOpen;

  /// 肚皮胀缩系数（吞金币储蓄罐：金币入肚后肚皮鼓起），1.0 为常态。
  final double bellyScale;

  /// 进化阶段 0~3（累计签到 0/7/30/100 天：奶泡／尖角／飞翼／金冠）。
  /// 养成的稀缺感＋回归动力，第1件专利的延续案口径见 stageName。
  final int evoStage;

  const MonsterIcon({
    super.key,
    this.size = 40,
    this.bodyColor,
    this.bellyColor,
    this.showCircle = false,
    this.circleColor,
    this.mouthOpen = 0.0,
    this.bellyScale = 1.0,
    this.evoStage = 0,
  });

  /// 累计签到天数 → 进化阶段（0/7/30/100）。
  static int stageFor(int totalDays) => totalDays >= 100
      ? 3
      : totalDays >= 30
      ? 2
      : totalDays >= 7
      ? 1
      : 0;

  /// 阶段名（展示＋专利延续案统一口径）。
  static String stageName(int stage) => const ['奶泡', '尖角', '飞翼', '金冠'][stage.clamp(0, 3)];

  /// 累计签到天数 → 肚皮基线（每天长大一点，上限 1.25，喂养感）。
  static double growthFor(int totalDays) => 1 + math.min(0.25, totalDays * 0.002);

  @override
  Widget build(BuildContext context) {
    final skin = SkinProvider.of(context);
    final body = bodyColor ?? skin.colors.accent; // 默认使用主题强调色（星巴克绿）
    final belly = bellyColor ?? MonsterPalette.belly; // 浅青色肚皮

    Widget painter = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MonsterPainter(
          bodyColor: body,
          bellyColor: belly,
          mouthOpen: mouthOpen.clamp(0.0, 1.0),
          bellyScale: bellyScale.clamp(0.6, 1.8),
          evoStage: evoStage.clamp(0, 3),
        ),
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
  final double mouthOpen;
  final double bellyScale;
  final int evoStage;

  _MonsterPainter({
    required this.bodyColor,
    required this.bellyColor,
    this.mouthOpen = 0.0,
    this.bellyScale = 1.0,
    this.evoStage = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.85;

    // === 0. 进化件（光环／飞翼，画在身体之前打底）===
    if (evoStage >= 3) {
      // 金冠光环：100 天形态的尊贵背光
      canvas.drawCircle(
        Offset(cx, cy),
        r * 1.02,
        Paint()
          ..color = MonsterPalette.evoGold
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.07
          ..strokeCap = StrokeCap.round,
      );
    }
    if (evoStage >= 2) {
      // 飞翼：30 天形态，左右各一叶（旋转椭圆打底＋羽线）
      final wingPaint = Paint()
        ..color = bodyColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;
      final wingLine = Paint()
        ..color = MonsterPalette.evoGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.035
        ..strokeCap = StrokeCap.round;
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(cx + side * r * 0.82, cy + r * 0.12);
        canvas.rotate(side * 0.55);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.6, height: r * 0.3), wingPaint);
        canvas.drawLine(Offset(-r * 0.2, 0), Offset(r * 0.2, 0), wingLine);
        canvas.restore();
      }
    }

    // === 1. 身体（圆润的怪兽主体）===
    final bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;

    // 主体：略椭圆的圆润形状
    final bodyRect = Rect.fromCenter(center: Offset(cx, cy + r * 0.05), width: r * 1.7, height: r * 1.6);
    canvas.drawOval(bodyRect, bodyPaint);

    // === 2. 肚皮（浅色椭圆，随 bellyScale 胀缩——储蓄罐鼓肚）===
    final bellyPaint = Paint()
      ..color = bellyColor
      ..style = PaintingStyle.fill;

    final bellyRect = Rect.fromCenter(
      center: Offset(cx, cy + r * 0.25),
      width: r * 1.0 * bellyScale,
      height: r * 0.85 * bellyScale,
    );
    canvas.drawOval(bellyRect, bellyPaint);

    // === 3. 角（头顶的小角；7 天镀金，30 天长大）===
    // 进化角半径：30 天形态角长 1/4，更威风。
    final hr = r * (evoStage >= 2 ? 1.25 : 1.0);
    final hornPaint = Paint()
      ..color = evoStage >= 1 ? MonsterPalette.evoGold : Colors.white
      ..style = PaintingStyle.fill;

    final hornPath = Path();
    hornPath.moveTo(cx - hr * 0.15, cy - hr * 0.65);
    hornPath.quadraticBezierTo(cx - hr * 0.05, cy - hr * 1.05, cx + hr * 0.05, cy - hr * 0.7);
    hornPath.quadraticBezierTo(cx, cy - hr * 0.55, cx - hr * 0.15, cy - hr * 0.65);
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
      ..color = MonsterPalette.eye
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

    // === 5. 嘴巴（小微笑 / 张开吃金币）===
    if (mouthOpen <= 0.01) {
      final mouthPaint = Paint()
        ..color = MonsterPalette.eye
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..strokeCap = StrokeCap.round;

      final mouthPath = Path();
      mouthPath.moveTo(cx - r * 0.12, cy + r * 0.18);
      mouthPath.quadraticBezierTo(cx, cy + r * 0.28, cx + r * 0.12, cy + r * 0.18);
      canvas.drawPath(mouthPath, mouthPaint);
    } else {
      // 张开的嘴：深色内腔椭圆 + 小舌头，随 mouthOpen 0→1 长大。
      final openH = (r * 0.34 * mouthOpen).clamp(1.0, r * 0.4);
      final openW = r * (0.22 + 0.14 * mouthOpen);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + r * 0.22), width: openW, height: openH),
        Paint()
          ..color = MonsterPalette.mouthInner
          ..style = PaintingStyle.fill,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + r * 0.22 + openH * 0.22), width: openW * 0.55, height: openH * 0.45),
        Paint()
          ..color = MonsterPalette.tongue
          ..style = PaintingStyle.fill,
      );
    }

    // === 6. 腮红（小粉红圆点）===
    final blushPaint = Paint()
      ..color = MonsterPalette.blush.withValues(alpha: 0.5)
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
    return oldDelegate.bodyColor != bodyColor ||
        oldDelegate.bellyColor != bellyColor ||
        oldDelegate.mouthOpen != mouthOpen ||
        oldDelegate.bellyScale != bellyScale ||
        oldDelegate.evoStage != evoStage;
  }
}

/// 带背景的怪兽圆形头像（用于尖叫币卡片）
class MonsterAvatar extends StatelessWidget {
  final double size;
  final Color? bgColor;

  /// 进化阶段（默认 0 奶泡；传累计签到换算的 stage 即可长大）。
  final int evoStage;

  const MonsterAvatar({super.key, this.size = 52, this.bgColor, this.evoStage = 0});

  @override
  Widget build(BuildContext context) {
    final skin = SkinProvider.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bgColor ?? skin.colors.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Center(
        child: MonsterIcon(size: size * 0.72, evoStage: evoStage),
      ),
    );
  }
}
