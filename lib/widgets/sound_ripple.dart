// 发音涟漪（SoundRipple）——点击发音按钮时三圈同心 ripple 扩散。
// 规格：AnimatedBuilder 驱动，1.2s 一轮（任务指定时长），跑完自停；
// 三圈起始 alpha 取 AppAlphas 递减档（o30 → o20 → o10），随扩散淡出至 o0。
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

/// 涟漪触发器：pulse() 触发一轮扩散，跑完自停；连续 pulse 会重新起跑。
class SoundRippleController extends ChangeNotifier {
  /// 触发一轮涟漪。
  void pulse() => notifyListeners();
}

/// 三圈同心涟漪包装器：包住发音图标等 child，[trigger].pulse() 即扩散一轮。
class SoundRipple extends StatefulWidget {
  const SoundRipple({super.key, required this.trigger, this.child, this.color, this.size = 28});

  final SoundRippleController trigger;
  final Widget? child;

  /// 涟漪颜色，缺省取当前皮肤 accent。
  final Color? color;

  /// 包裹区域的边长（涟漪可超出该范围扩散）。
  final double size;

  @override
  State<SoundRipple> createState() => SoundRippleState();
}

class SoundRippleState extends State<SoundRipple> with SingleTickerProviderStateMixin {
  /// 一轮时长（任务规格：1.2s 一轮，跑完自停；属环境/循环类长动效）。
  static const Duration _cycle = Duration(milliseconds: 1200);

  /// 单圈占整轮比例；三圈错峰 0.1，最后一圈恰在整轮内跑完。
  static const double _cycleShare = 0.75;
  static const double _stagger = 0.1;

  late final AnimationController controller = AnimationController(vsync: this, duration: _cycle);

  @override
  void initState() {
    super.initState();
    widget.trigger.addListener(_onPulse);
  }

  void _onPulse() {
    if (!mounted) return;
    controller.forward(from: 0);
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_onPulse);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? context.skin.colors.accent;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none, // 涟漪半径可超出包裹区，向外扩散
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                if (!controller.isAnimating) return const SizedBox.shrink();
                return CustomPaint(
                  painter: _SoundRipplePainter(progress: controller.value, color: baseColor),
                );
              },
            ),
          ),
          Center(child: widget.child),
        ],
      ),
    );
  }
}

class _SoundRipplePainter extends CustomPainter {
  _SoundRipplePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  /// 三圈起始 alpha 递减档（AppAlphas token）。
  static const List<double> _startAlphas = [AppAlphas.o30, AppAlphas.o20, AppAlphas.o10];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide * 0.8;
    for (var i = 0; i < _startAlphas.length; i++) {
      final t = ((progress - i * SoundRippleState._stagger) / SoundRippleState._cycleShare).clamp(0.0, 1.0);
      if (t <= 0) continue;
      canvas.drawCircle(
        center,
        maxRadius * (0.45 + 0.9 * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: _startAlphas[i] * (1 - t)),
      );
    }
  }

  @override
  bool shouldRepaint(_SoundRipplePainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.color != color;
}
