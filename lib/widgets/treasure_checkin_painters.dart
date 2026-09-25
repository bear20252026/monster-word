// part of treasure_checkin_page.dart — 聚宝日历绘制件（徽章 / 储蓄罐 / 粒子 / 币图标）。
part of 'treasure_checkin_page.dart';

/// 徽章外观状态。
enum _BadgeKind { checked, today, future, plain }

/// 12 瓣花齿印章徽章（专利特征①）。
class _SealBadge extends StatelessWidget {
  const _SealBadge({
    required this.kind,
    required this.num,
    required this.squareness,
    required this.glowAlpha,
    required this.reduceMotion,
  });

  final _BadgeKind kind;
  final int num;
  final double squareness;
  final double glowAlpha;
  final bool reduceMotion;

  static Color numColor(_BadgeKind kind) => switch (kind) {
    _BadgeKind.checked => TreasurePalette.checkedNum,
    _BadgeKind.today => TreasurePalette.todayNum,
    _BadgeKind.future => TreasurePalette.futureNum,
    _BadgeKind.plain => TreasurePalette.plainNum,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(44, 44),
            painter: _SealPainter(kind: kind, squareness: squareness, glowAlpha: glowAlpha),
          ),
          // 今日：品牌绿虚线旋转描边（聚合后持续旋转）。
          if (kind == _BadgeKind.today && !reduceMotion)
            const Positioned.fill(child: CustomPaint(painter: _DashedRingPainter())),
          Text(
            '$num',
            style: MwTypography.bodySm.copyWith(fontWeight: FontWeight.w800, color: numColor(kind)),
          ),
        ],
      ),
    );
  }
}

/// 印章绘制：花齿面 ⇄ 圆角方章交叉渐隐 + 爪印盖章。
class _SealPainter extends CustomPainter {
  _SealPainter({required this.kind, required this.squareness, required this.glowAlpha});

  final _BadgeKind kind;
  final double squareness;
  final double glowAlpha;

  /// 花齿极坐标轮廓（同原型 sealPath(24,24,22.4,2.8,12)）。
  static Path flowerPath(Size size) {
    final unit = size.width / 48;
    final cx = 24 * unit, cy = 24 * unit, R = 22.4 * unit, amp = 2.8 * unit;
    final path = Path();
    const n = 144;
    for (var i = 0; i <= n; i++) {
      final a = i / n * math.pi * 2;
      final rad = R - amp * (0.5 - 0.5 * math.cos(12 * a));
      final x = cx + math.cos(a - math.pi / 2) * rad;
      final y = cy + math.sin(a - math.pi / 2) * rad;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 48;
    final center = Offset(size.width / 2, size.height / 2);

    // 盖章光晕（签到瞬间）。
    if (glowAlpha > 0) {
      canvas.drawCircle(
        center,
        40 * unit,
        Paint()
          ..shader = RadialGradient(
            colors: [
              TreasurePalette.gold.withValues(alpha: glowAlpha),
              TreasurePalette.gold.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: 40 * unit)),
      );
    }

    final flower = flowerPath(size);
    final square = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(2 * unit, 2 * unit, 46 * unit, 46 * unit), Radius.circular(8 * unit)),
      );

    final stroke = Paint()
      ..color = TreasurePalette.faceStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit;

    // 金色渐变（已签）：#ffd97a → #f6bd45 → #d99a26。
    final Shader? shader;
    if (kind == _BadgeKind.checked) {
      shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [TreasurePalette.goldLight, TreasurePalette.gold, TreasurePalette.goldDeep],
        stops: const [0, 0.55, 1],
      ).createShader(Rect.fromCircle(center: center, radius: 23 * unit));
    } else {
      shader = null;
    }

    final facePaint = Paint()..color = faceColor(kind);
    if (shader != null) facePaint.shader = shader;

    // 花齿面（散落态）与方章面（聚合态）交叉渐隐。
    final flowerAlpha = 1 - squareness;
    if (flowerAlpha > 0) {
      canvas.saveLayer(flower.getBounds(), Paint()..color = Colors.white.withValues(alpha: flowerAlpha));
      canvas.drawPath(flower, facePaint);
      canvas.drawPath(flower, stroke);
      canvas.restore();
    }
    if (squareness > 0) {
      canvas.saveLayer(square.getBounds(), Paint()..color = Colors.white.withValues(alpha: squareness));
      canvas.drawPath(square, facePaint);
      canvas.drawPath(square, stroke);
      canvas.restore();
    }

    // 爪印盖章（仅已签态，压章色 #8a5a00）。
    if (kind == _BadgeKind.checked) {
      final paw = Paint()..color = TreasurePalette.stampGold.withValues(alpha: 0.9);
      final s = unit;
      canvas.save();
      canvas.translate(24 * s, 24 * s);
      canvas.drawOval(Rect.fromCenter(center: Offset(0, 2.5 * s), width: 10.4 * s, height: 8.8 * s), paw);
      canvas.drawCircle(Offset(-5 * s, -4.5 * s), 2.1 * s, paw);
      canvas.drawCircle(Offset(0, -6.2 * s), 2.1 * s, paw);
      canvas.drawCircle(Offset(5 * s, -4.5 * s), 2.1 * s, paw);
      canvas.restore();
    }
  }

  static Color faceColor(_BadgeKind kind) => switch (kind) {
    _BadgeKind.checked => TreasurePalette.gold,
    _BadgeKind.today => TreasurePalette.card,
    _BadgeKind.future => TreasurePalette.futureFace,
    _BadgeKind.plain => TreasurePalette.card,
  };

  @override
  bool shouldRepaint(covariant _SealPainter old) =>
      old.kind != kind || old.squareness != squareness || old.glowAlpha != glowAlpha;
}

/// 今日徽章的品牌绿虚线旋转描边（14s/圈）。
class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 + 7;
    final angle = (DateTime.now().millisecondsSinceEpoch % 14000) / 14000 * 2 * math.pi;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final paint = Paint()
      ..color = TreasurePalette.green.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const dashes = 22;
    final sweep = 2 * math.pi / dashes * 0.55;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(Offset.zero & Size.fromRadius(radius), i * 2 * math.pi / dashes, sweep, false, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) => true;
}

/// 小怪兽储蓄罐（专利特征④，几何同原型 piggy SVG 220×128）。
class _PiggyPainter extends CustomPainter {
  _PiggyPainter({required this.bellyPct});

  final double bellyPct;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 220;

    Paint paint(Color c) => Paint()..color = c;

    // 橙色小脚。
    canvas.drawOval(
      Rect.fromCenter(center: Offset(82 * s, 120 * s), width: 32 * s, height: 16 * s),
      paint(TreasurePalette.pigAccent),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(138 * s, 120 * s), width: 32 * s, height: 16 * s),
      paint(TreasurePalette.pigAccent),
    );

    // 青绿圆身（上浅下深渐变）。
    final bodyShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [TreasurePalette.pigSkinTop, TreasurePalette.pigSkinBottom],
    ).createShader(Rect.fromCenter(center: Offset(110 * s, 82 * s), width: 144 * s, height: 92 * s));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(110 * s, 82 * s), width: 144 * s, height: 92 * s),
      Paint()..shader = bodyShader,
    );

    // 橙色小角。
    final horn = Path()
      ..moveTo(84 * s, 42 * s)
      ..quadraticBezierTo(80 * s, 26 * s, 92 * s, 24 * s)
      ..quadraticBezierTo(100 * s, 23 * s, 100 * s, 36 * s)
      ..close();
    canvas.drawPath(horn, paint(TreasurePalette.pigAccent));
    final horn2 = Path()
      ..moveTo(136 * s, 42 * s)
      ..quadraticBezierTo(140 * s, 26 * s, 128 * s, 24 * s)
      ..quadraticBezierTo(120 * s, 23 * s, 120 * s, 36 * s)
      ..close();
    canvas.drawPath(horn2, paint(TreasurePalette.pigAccent));

    // 侧鳍小手。
    canvas.save();
    canvas.translate(40 * s, 92 * s);
    canvas.rotate(0.31);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 20 * s, height: 28 * s),
      paint(TreasurePalette.pigSkinBottom),
    );
    canvas.restore();
    canvas.save();
    canvas.translate(180 * s, 92 * s);
    canvas.rotate(-0.31);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 20 * s, height: 28 * s),
      paint(TreasurePalette.pigSkinBottom),
    );
    canvas.restore();

    // 肚皮视窗：底色 + 金位上涨（clip 椭圆）+ 奶白描边。
    final bellyRect = Rect.fromCenter(center: Offset(110 * s, 90 * s), width: 104 * s, height: 52 * s);
    canvas.drawOval(bellyRect, paint(TreasurePalette.pigBellyBack));
    canvas.save();
    canvas.clipPath(Path()..addOval(bellyRect));
    final fillY = (122 - 60 * bellyPct) * s;
    canvas.drawRect(Rect.fromLTRB(54 * s, fillY, 166 * s, 176 * s), paint(TreasurePalette.gold));
    // 金面上的高光泡。
    final bubble = paint(TreasurePalette.goldSoft.withValues(alpha: 0.9));
    canvas.drawCircle(Offset(88 * s, 116 * s), 6.5 * s, bubble);
    canvas.drawCircle(Offset(112 * s, 118 * s), 6.5 * s, bubble);
    canvas.drawCircle(Offset(136 * s, 116 * s), 6.5 * s, bubble);
    canvas.restore();
    canvas.drawOval(
      bellyRect,
      Paint()
        ..color = TreasurePalette.cream
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * s,
    );

    // 黑豆眼 + 微笑 + 浅色腮红。
    canvas.drawCircle(Offset(88 * s, 52 * s), 4.2 * s, paint(TreasurePalette.pigDark));
    canvas.drawCircle(Offset(132 * s, 52 * s), 4.2 * s, paint(TreasurePalette.pigDark));
    final smile = Path()
      ..moveTo(102 * s, 60 * s)
      ..quadraticBezierTo(110 * s, 67 * s, 118 * s, 60 * s);
    canvas.drawPath(
      smile,
      Paint()
        ..color = TreasurePalette.pigDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * s
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(74 * s, 62 * s), 5 * s, paint(TreasurePalette.pigBlush));
    canvas.drawCircle(Offset(146 * s, 62 * s), 5 * s, paint(TreasurePalette.pigBlush));

    // 胸前 W（呼应 App 图标）。
    final w = Path()
      ..moveTo(80 * s, 102 * s)
      ..lineTo(90 * s, 124 * s)
      ..lineTo(102 * s, 108 * s)
      ..lineTo(110 * s, 120 * s)
      ..lineTo(118 * s, 108 * s)
      ..lineTo(130 * s, 124 * s)
      ..lineTo(140 * s, 102 * s);
    canvas.drawPath(
      w,
      Paint()
        ..color = TreasurePalette.cream
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PiggyPainter old) => old.bellyPct != bellyPct;
}

/// 全页粒子层：氛围微尘 + 环绕尘粒 + 金币弹道（页面坐标系）。
class _FxPainter extends CustomPainter {
  _FxPainter({required this.state});

  final _TreasureCheckInPageState state;

  @override
  void paint(Canvas canvas, Size size) {
    final st = state;
    if (st._stageW <= 0) return;

    // 氛围微尘。
    final ambientPaint = Paint()..color = TreasurePalette.dust;
    for (final a in st._ambient) {
      ambientPaint.color = TreasurePalette.dust.withValues(alpha: 0.10 + 0.10 * (0.5 + 0.5 * math.sin(a.tw)));
      canvas.drawCircle(Offset(_stageOriginX(st) + a.x, _stageOriginY(st) + a.y), a.size, ambientPaint);
    }

    // 环绕尘粒（绕徽章 / 螺旋吸入）。
    for (final p in st._dust) {
      final d = st._days[p.part];
      final px = _stageOriginX(st) + d.x + math.cos(p.ang) * p.rad;
      final py = _stageOriginY(st) + d.y + math.sin(p.ang) * p.rad * 0.82;
      canvas.drawCircle(
        Offset(px, py),
        p.size,
        Paint()..color = TreasurePalette.coinColors[p.color].withValues(alpha: p.alpha.clamp(0.0, 1.0)),
      );
    }

    // 金币弹道：二次贝塞尔 + smoothstep（专利特征③）。
    for (final c in st._burst) {
      final u = ((st._now - c.t0) / c.dur).clamp(0.0, 1.0);
      if (u <= 0) continue;
      final e = u * u * (3 - 2 * u);
      final x = (1 - e) * (1 - e) * c.sx + 2 * (1 - e) * e * c.cx + e * e * st._bellyPoint.dx;
      final y = (1 - e) * (1 - e) * c.sy + 2 * (1 - e) * e * c.cy + e * e * st._bellyPoint.dy;
      canvas.drawCircle(
        Offset(x, y),
        c.size * (1 - u * 0.35),
        Paint()..color = TreasurePalette.coinColors[c.color].withValues(alpha: 1 - u * u * 0.4),
      );
    }
  }

  double _stageOriginX(_TreasureCheckInPageState st) => st._stageOrigin.dx;
  double _stageOriginY(_TreasureCheckInPageState st) => st._stageOrigin.dy;

  @override
  bool shouldRepaint(covariant _FxPainter old) => true;
}

/// 金币小图标（顶部余额胶囊 / CTA）。
class _CoinGlyph extends StatelessWidget {
  const _CoinGlyph({required this.size, this.creamStyle = false});

  final double size;
  final bool creamStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CoinGlyphPainter(creamStyle: creamStyle)),
    );
  }
}

class _CoinGlyphPainter extends CustomPainter {
  const _CoinGlyphPainter({required this.creamStyle});

  final bool creamStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final center = Offset(12 * s, 12 * s);
    if (creamStyle) {
      // CTA 上的奶白半透明币。
      canvas.drawCircle(center, 9 * s, Paint()..color = TreasurePalette.cream.withValues(alpha: 0.25));
      _paintSymbol(canvas, s, TreasurePalette.cream.withValues(alpha: 0.9));
    } else {
      // 余额胶囊上的金底币。
      canvas.drawCircle(center, 9 * s, Paint()..color = TreasurePalette.gold);
      canvas.drawCircle(
        center,
        6.2 * s,
        Paint()
          ..color = TreasurePalette.goldDeep
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s,
      );
      _paintSymbol(canvas, s, TreasurePalette.goldDeep);
    }
  }

  void _paintSymbol(Canvas canvas, double s, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(12 * s, 8.4 * s), Offset(12 * s, 15.6 * s), paint);
    canvas.drawLine(Offset(9.6 * s, 10 * s), Offset(14.4 * s, 10 * s), paint);
    canvas.drawLine(Offset(9.6 * s, 14 * s), Offset(14.4 * s, 14 * s), paint);
  }

  @override
  bool shouldRepaint(covariant _CoinGlyphPainter old) => old.creamStyle != creamStyle;
}
