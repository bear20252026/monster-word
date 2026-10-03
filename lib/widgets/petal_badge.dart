// 花齿义项序号徽章（PetalBadge）——12 瓣花齿几何复用聚宝签到印章。
// 几何来源：lib/features/checkin/presentation/treasure_checkin_painters.dart
// 的 _SealPainter.flowerPath（原型 sealPath(24,24,22.4,2.8,12)）：
//   r = R − amp·(0.5 − 0.5·cos(12θ))，R = 22.4u，amp = 2.8u，u = size/48，
//   144 段折线闭合，起始角 −π/2（第一齿朝上）。
// 本文件为独立纯 painter 复制该公式，不修改原文件。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

/// 义项序号徽章：花齿底 + 序号（或自定义 child）。
///
/// [index] 为义项序号（1 起）；[total] 缺省按 12 瓣绘制，传入义项总数时以该值
/// 作为花齿数；[color] 缺省取当前皮肤 accent。
class PetalBadge extends StatelessWidget {
  const PetalBadge({super.key, required this.index, this.total, this.size = 24, this.color, this.child});

  final int index;
  final int? total;
  final double size;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? context.skin.colors.accent;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: PetalFlowerPainter(color: baseColor, petals: total ?? 12),
            ),
          ),
          // 缺省渲染序号数字；调用方传 child 时以 child 为准。
          child ?? Text('$index', style: MwTypography.microXs.copyWith(color: baseColor)),
        ],
      ),
    );
  }
}

/// 花齿轮廓 painter（几何公式与 _SealPainter.flowerPath 一致，仅参数化花齿数）。
class PetalFlowerPainter extends CustomPainter {
  PetalFlowerPainter({required this.color, this.petals = 12});

  final Color color;
  final int petals;

  @override
  void paint(Canvas canvas, Size size) {
    final path = flowerPath(size, petals);
    // 淡色花齿面 + 同色细描边（alpha 均取 token 档位）。
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: AppAlphas.o14));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width / 48
        ..color = color.withValues(alpha: AppAlphas.o40),
    );
  }

  /// 花齿极坐标轮廓：r = R − amp·(0.5 − 0.5·cos(petals·θ))，
  /// R = 22.4u、amp = 2.8u、u = size/48，144 段折线闭合，起始角 −π/2。
  static Path flowerPath(Size size, int petals) {
    final unit = size.width / 48;
    final cx = 24 * unit, cy = 24 * unit, R = 22.4 * unit, amp = 2.8 * unit;
    final path = Path();
    const n = 144;
    for (var i = 0; i <= n; i++) {
      final a = i / n * math.pi * 2;
      final rad = R - amp * (0.5 - 0.5 * math.cos(petals * a));
      final x = cx + math.cos(a - math.pi / 2) * rad;
      final y = cy + math.sin(a - math.pi / 2) * rad;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(PetalFlowerPainter oldDelegate) => oldDelegate.color != color || oldDelegate.petals != petals;
}
