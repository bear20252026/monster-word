// 由 Claude 团队 生成 | Monster Word App

// 共享盒式磁带组件：随身听家族（personal_stereo / listening_player）的
// 统一播放状态隐喻——播放中双卷轴持续旋转，暂停即停转。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

/// 盒式磁带：奶油机身 + 双卷轴 + 磁带窗；[spinning] 为真时卷轴持续旋转。
class CassetteTape extends StatefulWidget {
  const CassetteTape({super.key, this.spinning = false, this.size = const Size(176, 92)});

  final bool spinning;

  /// 磁带整体尺寸（宽 × 高）。
  final Size size;

  @override
  State<CassetteTape> createState() => _CassetteTapeState();
}

class _CassetteTapeState extends State<CassetteTape> with SingleTickerProviderStateMixin {
  late final AnimationController _reel = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _reel.repeat();
  }

  @override
  void didUpdateWidget(CassetteTape old) {
    super.didUpdateWidget(old);
    if (widget.spinning == old.spinning) return;
    widget.spinning ? _reel.repeat() : _reel.stop();
  }

  @override
  void dispose() {
    _reel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reelSize = widget.size.height * 0.44;
    return Container(
      width: widget.size.width,
      height: widget.size.height,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white100,
        borderRadius: BorderRadius.circular(context.design.radius.md),
        border: Border.all(color: context.skin.colors.text2.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: context.skin.colors.text1.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _spinningReel(reelSize),
          Container(
            width: reelSize * 0.72,
            height: reelSize * 0.6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.design.radius.xs),
              border: Border.all(color: context.skin.colors.text2.withValues(alpha: 0.5), width: 2),
            ),
          ),
          _spinningReel(reelSize),
        ],
      ),
    );
  }

  Widget _spinningReel(double size) {
    return AnimatedBuilder(
      animation: _reel,
      builder: (context, child) => Transform.rotate(angle: _reel.value * 2 * math.pi, child: child),
      child: CustomPaint(
        size: Size(size, size),
        painter: _ReelPainter(color: context.skin.colors.text1),
      ),
    );
  }
}

/// 卷轴：外圈 + 三辐条 + 轴心。
class _ReelPainter extends CustomPainter {
  _ReelPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 2;

    canvas.drawCircle(center, radius, paint);
    for (var i = 0; i < 3; i++) {
      final angle = i * 2 * math.pi / 3;
      canvas.drawLine(
        center + Offset(math.cos(angle) * radius * 0.25, math.sin(angle) * radius * 0.25),
        center + Offset(math.cos(angle) * radius * 0.92, math.sin(angle) * radius * 0.92),
        paint,
      );
    }
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.2, paint);
  }

  @override
  bool shouldRepaint(_ReelPainter oldDelegate) => color != oldDelegate.color;
}
