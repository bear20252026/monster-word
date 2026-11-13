// 记忆兽图鉴渲染（蓝图 T3 demo）：同一骨骼模板 × 生成规格。
//
// 与陪伴怪兽（monster_icon.dart）是两个物种：陪伴兽只有一只、随天数进化；
// 记忆兽一词一只、由词属性程序化生成。本组件不 import 陪伴兽，避免污染
// 其「唯一陪伴」契约；画风沿用同款圆润比例与 MonsterPalette 五官件。
//
// 颜色一律走具名 token（MemoryBeastPalette/MonsterPalette/AppColors），
// 组件内零 Color(0x…) 字面量（color_hygiene 守卫）。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:word_app/core/utils/memory_beast.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/effect_palette.dart';

/// 一只记忆兽（静态渲染，无动画——图鉴 demo 先验证「可爱不恐怖」）。
class MemoryBeastIcon extends StatelessWidget {
  const MemoryBeastIcon({super.key, required this.spec, this.size = 72});

  final MemoryBeastSpec spec;
  final double size;

  /// 稀有度 → 具名配色（单源，渲染与图例共用）。
  static Color colorFor(BeastRarity rarity) => switch (rarity) {
    BeastRarity.common => MemoryBeastPalette.common,
    BeastRarity.uncommon => MemoryBeastPalette.uncommon,
    BeastRarity.rare => MemoryBeastPalette.rare,
  };

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MemoryBeastPainter(spec: spec),
    );
  }
}

class _MemoryBeastPainter extends CustomPainter {
  _MemoryBeastPainter({required this.spec});

  final MemoryBeastSpec spec;

  // P3-3（架构审计 2026-11-12）：Paint 改实例字段——原 static 可变 Paint 被多个
  // painter 实例共享，改色会理论串色（单线程绘制实际无碍，但多实例并发即隐患）。
  // 每次 build 新建 painter，实例 Paint 开销可忽略。
  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.72;
    final body = MemoryBeastIcon.colorFor(spec.rarity);
    final w = spec.bodyWidthFactor;
    final h = spec.bodyHeightFactor;

    // === 1. 耳朵（画在身体之后打底；词性决定形态）===
    _paintEars(canvas, cx, cy, r, body, w, h);

    // === 2. 身体（词长决定宽高比）===
    _fill.color = body;
    final bodyRect = Rect.fromCenter(center: Offset(cx, cy + r * 0.05), width: r * 1.7 * w, height: r * 1.6 * h);
    canvas.drawOval(bodyRect, _fill);

    // === 3. 肚皮 ===
    _fill.color = MonsterPalette.belly;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + r * 0.28 * h), width: r * 0.95 * w, height: r * 0.8 * h),
      _fill,
    );

    // === 4. 眼睛（大眼 + 瞳孔 + 高光，可爱感的核心）===
    _fill.color = AppColors.white100;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.28 * w, cy - r * 0.15 * h), width: r * 0.42, height: r * 0.48),
      _fill,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + r * 0.28 * w, cy - r * 0.15 * h), width: r * 0.38, height: r * 0.44),
      _fill,
    );
    _fill.color = MonsterPalette.eye;
    canvas.drawCircle(Offset(cx - r * 0.22 * w, cy - r * 0.12 * h), r * 0.13, _fill);
    canvas.drawCircle(Offset(cx + r * 0.32 * w, cy - r * 0.12 * h), r * 0.12, _fill);
    _fill.color = AppColors.white100;
    canvas.drawCircle(Offset(cx - r * 0.18 * w, cy - r * 0.2 * h), r * 0.05, _fill);
    canvas.drawCircle(Offset(cx + r * 0.36 * w, cy - r * 0.2 * h), r * 0.045, _fill);

    // === 5. 微笑 ===
    _line
      ..color = MonsterPalette.eye
      ..strokeWidth = r * 0.05;
    final mouth = Path();
    mouth.moveTo(cx - r * 0.12, cy + r * 0.18 * h);
    mouth.quadraticBezierTo(cx, cy + r * 0.28 * h, cx + r * 0.12, cy + r * 0.18 * h);
    canvas.drawPath(mouth, _line);

    // === 6. 腮红 ===
    _fill.color = MonsterPalette.blush.withValues(alpha: AppAlphas.o60);
    canvas.drawCircle(Offset(cx - r * 0.45 * w, cy + r * 0.05 * h), r * 0.08, _fill);
    canvas.drawCircle(Offset(cx + r * 0.45 * w, cy + r * 0.05 * h), r * 0.08, _fill);

    // === 7. 手脚 ===
    _fill.color = body;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.75 * w, cy + r * 0.1 * h), width: r * 0.3, height: r * 0.25),
      _fill,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + r * 0.75 * w, cy + r * 0.1 * h), width: r * 0.3, height: r * 0.25),
      _fill,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.25 * w, cy + r * 0.75 * h), width: r * 0.3, height: r * 0.2),
      _fill,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + r * 0.25 * w, cy + r * 0.75 * h), width: r * 0.3, height: r * 0.2),
      _fill,
    );
  }

  /// 四种耳朵：圆耳（名词）/尖耳（动词）/垂耳（形容词）/角耳（副词）。
  void _paintEars(Canvas canvas, double cx, double cy, double r, Color body, double w, double h) {
    _fill.color = body;
    final topY = cy - r * 0.62 * h;
    final dx = r * 0.42 * w;
    switch (spec.ears) {
      case BeastEars.round:
        canvas.drawCircle(Offset(cx - dx, topY), r * 0.22, _fill);
        canvas.drawCircle(Offset(cx + dx, topY), r * 0.22, _fill);
      case BeastEars.pointy:
        for (final side in [-1.0, 1.0]) {
          final p = Path();
          p.moveTo(cx + side * dx - r * 0.16, topY + r * 0.18);
          p.lineTo(cx + side * dx + side * r * 0.06, topY - r * 0.34);
          p.lineTo(cx + side * dx + r * 0.16, topY + r * 0.18);
          p.close();
          canvas.drawPath(p, _fill);
        }
      case BeastEars.floppy:
        for (final side in [-1.0, 1.0]) {
          canvas.save();
          canvas.translate(cx + side * dx, topY + r * 0.1);
          canvas.rotate(side * 0.5);
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.2, height: r * 0.44), _fill);
          canvas.restore();
        }
      case BeastEars.tufted:
        for (final side in [-1.0, 1.0]) {
          final p = Path();
          p.moveTo(cx + side * dx - r * 0.1, topY + r * 0.16);
          p.quadraticBezierTo(
            cx + side * dx + side * r * 0.14,
            topY - r * 0.3,
            cx + side * dx + side * r * 0.02,
            topY - r * 0.34,
          );
          p.quadraticBezierTo(
            cx + side * dx + side * r * 0.2,
            topY - r * 0.1,
            cx + side * dx + r * 0.1,
            topY + r * 0.16,
          );
          p.close();
          canvas.drawPath(p, _fill);
        }
    }
  }

  @override
  bool shouldRepaint(covariant _MemoryBeastPainter oldDelegate) =>
      oldDelegate.spec.word != spec.word ||
      oldDelegate.spec.build != spec.build ||
      oldDelegate.spec.ears != spec.ears ||
      oldDelegate.spec.rarity != spec.rarity;
}
