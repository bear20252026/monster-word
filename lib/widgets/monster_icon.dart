// 怪兽尖叫币图标 — CustomPainter 绘制
// 基于用户提供的怪兽形象：圆润可爱的独角怪兽，青绿色皮肤，大眼睛小嘴巴
import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/effect_palette.dart';
import 'package:word_app/tokens/design_tokens.dart';

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

  /// 腮帮鼓起 0~1（饱嗝时刻双颊 puff，平时为 0）。
  final double cheekPuff;

  /// 难过表情（答错反馈用）：瞳孔下垂 + 撇嘴 + 眼角挂泪光。
  /// 多邻国式「怪兽陪你有喜有忧」——答对它欢呼，答错它先替你难过一下。
  final bool sad;

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
    this.cheekPuff = 0.0,
    this.sad = false,
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
          cheekPuff: cheekPuff.clamp(0.0, 1.0),
          sad: sad,
        ),
      ),
    );

    if (showCircle) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: circleColor ?? body.withValues(alpha: AppAlphas.o15),
          shape: BoxShape.circle,
        ),
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
  final double cheekPuff;
  final bool sad;

  _MonsterPainter({
    required this.bodyColor,
    required this.bellyColor,
    this.mouthOpen = 0.0,
    this.bellyScale = 1.0,
    this.evoStage = 0,
    this.cheekPuff = 0.0,
    this.sad = false,
  });

  // 性能审计：paint() 单次分配 ~16 个 Paint；本 painter 被喂币/吞币/首页
  // AnimatedBuilder 逐帧驱动时即每帧 16 次分配。固定色画笔提为 static
  // final；参数化画笔（颜色随主题、线宽随 r）复用 static 可变画笔并在
  // 每次使用前重设字段——paint 在 UI 线程同帧内顺序执行，与 halo_search
  // 的 _sharedPaint 同一口径。
  static final Paint _haloPaint = Paint()
    ..color = MonsterPalette.evoGold
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _wingLinePaint = Paint()
    ..color = MonsterPalette.evoGold
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _eyeWhitePaint = Paint()
    ..color = AppColors.white100
    ..style = PaintingStyle.fill;
  static final Paint _highlightPaint = Paint()
    ..color = AppColors.white100
    ..style = PaintingStyle.fill;
  static final Paint _pupilPaint = Paint()
    ..color = MonsterPalette.eye
    ..style = PaintingStyle.fill;
  static final Paint _mouthInnerPaint = Paint()
    ..color = MonsterPalette.mouthInner
    ..style = PaintingStyle.fill;
  static final Paint _tonguePaint = Paint()
    ..color = MonsterPalette.tongue
    ..style = PaintingStyle.fill;
  static final Paint _wingFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _bodyPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _bellyPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _hornPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _hornLinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _mouthPaint = Paint()
    ..color = MonsterPalette.eye
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _blushPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _limbPaint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.85;

    // === 0. 进化件（光环／飞翼，画在身体之前打底）===
    if (evoStage >= 3) {
      // 金冠光环：100 天形态的尊贵背光
      _haloPaint.strokeWidth = r * 0.07;
      canvas.drawCircle(Offset(cx, cy), r * 1.02, _haloPaint);
    }
    if (evoStage >= 2) {
      // 飞翼：30 天形态，左右各一叶（旋转椭圆打底＋羽线）
      _wingFillPaint.color = bodyColor.withValues(alpha: AppAlphas.o90);
      _wingLinePaint.strokeWidth = r * 0.035;
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(cx + side * r * 0.82, cy + r * 0.12);
        canvas.rotate(side * 0.55);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.6, height: r * 0.3), _wingFillPaint);
        canvas.drawLine(Offset(-r * 0.2, 0), Offset(r * 0.2, 0), _wingLinePaint);
        canvas.restore();
      }
    }

    // === 1. 身体（圆润的怪兽主体）===
    _bodyPaint.color = bodyColor;

    // 主体：略椭圆的圆润形状
    final bodyRect = Rect.fromCenter(center: Offset(cx, cy + r * 0.05), width: r * 1.7, height: r * 1.6);
    canvas.drawOval(bodyRect, _bodyPaint);

    // === 2. 肚皮（浅色椭圆，随 bellyScale 胀缩——储蓄罐鼓肚）===
    _bellyPaint.color = bellyColor;

    final bellyRect = Rect.fromCenter(
      center: Offset(cx, cy + r * 0.25),
      width: r * 1.0 * bellyScale,
      height: r * 0.85 * bellyScale,
    );
    canvas.drawOval(bellyRect, _bellyPaint);

    // === 3. 角（头顶的小角；7 天镀金，30 天长大）===
    // 进化角半径：30 天形态角长 1/4，更威风。
    final hr = r * (evoStage >= 2 ? 1.25 : 1.0);
    _hornPaint.color = evoStage >= 1 ? MonsterPalette.evoGold : AppColors.white100;

    final hornPath = Path();
    hornPath.moveTo(cx - hr * 0.15, cy - hr * 0.65);
    hornPath.quadraticBezierTo(cx - hr * 0.05, cy - hr * 1.05, cx + hr * 0.05, cy - hr * 0.7);
    hornPath.quadraticBezierTo(cx, cy - hr * 0.55, cx - hr * 0.15, cy - hr * 0.65);
    hornPath.close();
    canvas.drawPath(hornPath, _hornPaint);

    // 角上的小纹路
    _hornLinePaint
      ..color = bodyColor.withValues(alpha: AppAlphas.o30)
      ..strokeWidth = r * 0.04;
    canvas.drawLine(Offset(cx - r * 0.08, cy - r * 0.75), Offset(cx + r * 0.0, cy - r * 0.68), _hornLinePaint);

    // === 4. 眼睛（大眼睛，左眼略大）===
    // 左眼白
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.28, cy - r * 0.15), width: r * 0.42, height: r * 0.48),
      _eyeWhitePaint,
    );

    // 右眼白
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + r * 0.28, cy - r * 0.15), width: r * 0.38, height: r * 0.44),
      _eyeWhitePaint,
    );

    // 瞳孔（难过时下垂：视线落地面 + 双眼靠拢一点，委屈感）
    final sadDrop = sad ? r * 0.09 : 0.0;
    final sadPinch = sad ? r * 0.05 : 0.0;
    // 左瞳孔
    canvas.drawCircle(Offset(cx - r * 0.22 + sadPinch, cy - r * 0.12 + sadDrop), r * 0.13, _pupilPaint);
    // 右瞳孔
    canvas.drawCircle(Offset(cx + r * 0.32 - sadPinch, cy - r * 0.12 + sadDrop), r * 0.12, _pupilPaint);

    // 高光（难过时高光也随瞳孔下移，「眼里没光」的落寞感）
    canvas.drawCircle(Offset(cx - r * 0.18 + sadPinch, cy - r * 0.2 + sadDrop), r * 0.05, _highlightPaint);
    canvas.drawCircle(Offset(cx + r * 0.36 - sadPinch, cy - r * 0.2 + sadDrop), r * 0.045, _highlightPaint);

    // 难过眉：内高外低的斜眉（担忧脸）；正常态不画眉（干净）。
    if (sad) {
      _mouthPaint.strokeWidth = r * 0.045;
      canvas.drawLine(Offset(cx - r * 0.42, cy - r * 0.38), Offset(cx - r * 0.12, cy - r * 0.30), _mouthPaint);
      canvas.drawLine(Offset(cx + r * 0.12, cy - r * 0.30), Offset(cx + r * 0.40, cy - r * 0.38), _mouthPaint);
      // 眼角泪光：右眼外角一颗小水珠。
      _highlightPaint.color = MwColors.info;
      canvas.drawCircle(Offset(cx + r * 0.48, cy - r * 0.04), r * 0.05, _highlightPaint);
      _highlightPaint.color = AppColors.white100;
    }

    // === 5. 嘴巴（小微笑 / 张开吃金币 / 难过撇嘴）===
    if (sad && mouthOpen <= 0.01) {
      // 撇嘴：下弯小弧（替你难过的表情，不指责）。
      _mouthPaint.strokeWidth = r * 0.05;
      final mouthPath = Path();
      mouthPath.moveTo(cx - r * 0.12, cy + r * 0.26);
      mouthPath.quadraticBezierTo(cx, cy + r * 0.16, cx + r * 0.12, cy + r * 0.26);
      canvas.drawPath(mouthPath, _mouthPaint);
    } else if (mouthOpen <= 0.01) {
      _mouthPaint.strokeWidth = r * 0.05;

      final mouthPath = Path();
      mouthPath.moveTo(cx - r * 0.12, cy + r * 0.18);
      mouthPath.quadraticBezierTo(cx, cy + r * 0.28, cx + r * 0.12, cy + r * 0.18);
      canvas.drawPath(mouthPath, _mouthPaint);
    } else {
      // 张开的嘴：深色内腔椭圆 + 小舌头，随 mouthOpen 0→1 长大。
      final openH = (r * 0.34 * mouthOpen).clamp(1.0, r * 0.4);
      final openW = r * (0.22 + 0.14 * mouthOpen);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + r * 0.22), width: openW, height: openH),
        _mouthInnerPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + r * 0.22 + openH * 0.22), width: openW * 0.55, height: openH * 0.45),
        _tonguePaint,
      );
    }

    // === 6. 腮红（小粉红圆点；饱嗝时随 cheekPuff 鼓成大气球）===
    _blushPaint.color = MonsterPalette.blush.withValues(alpha: 0.5 + 0.3 * cheekPuff);
    final blushR = r * 0.08 * (1 + 0.9 * cheekPuff);
    canvas.drawCircle(Offset(cx - r * 0.45, cy + r * 0.05), blushR, _blushPaint);
    canvas.drawCircle(Offset(cx + r * 0.45, cy + r * 0.05), blushR, _blushPaint);

    // === 7. 小手（左右各一只）===
    _limbPaint.color = bodyColor;

    // 左手
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.75, cy + r * 0.1), width: r * 0.3, height: r * 0.25),
      _limbPaint,
    );
    // 右手
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + r * 0.75, cy + r * 0.1), width: r * 0.3, height: r * 0.25),
      _limbPaint,
    );

    // === 8. 脚（两个小脚丫）===
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.25, cy + r * 0.75), width: r * 0.3, height: r * 0.2),
      _limbPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + r * 0.25, cy + r * 0.75), width: r * 0.3, height: r * 0.2),
      _limbPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MonsterPainter oldDelegate) {
    return oldDelegate.bodyColor != bodyColor ||
        oldDelegate.bellyColor != bellyColor ||
        oldDelegate.mouthOpen != mouthOpen ||
        oldDelegate.bellyScale != bellyScale ||
        oldDelegate.evoStage != evoStage ||
        oldDelegate.cheekPuff != cheekPuff ||
        oldDelegate.sad != sad;
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
      decoration: BoxDecoration(
        color: bgColor ?? skin.colors.accent.withValues(alpha: AppAlphas.o12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: MonsterIcon(size: size * 0.72, evoStage: evoStage),
      ),
    );
  }
}
