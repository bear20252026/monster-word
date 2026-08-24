// Halo 搜索：带光晕背景的搜索框，聚焦时产生柔和光晕扩散效果
// 颜色可自定义，支持主题色适配
// 适用于：搜索页顶部搜索框、全局搜索入口
import 'dart:math' as math;
import 'package:flutter/material.dart';

class HaloSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Color? haloColor;
  final Color? bgColor;
  final double borderRadius;
  final EdgeInsets padding;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool autoFocus;

  const HaloSearchField({
    super.key,
    this.controller,
    this.hintText = '搜索单词...',
    this.onSubmitted,
    this.onChanged,
    this.haloColor,
    this.bgColor,
    this.borderRadius = 24,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.textStyle,
    this.hintStyle,
    this.prefixIcon,
    this.suffixIcon,
    this.autoFocus = false,
  });

  @override
  State<HaloSearchField> createState() => _HaloSearchFieldState();
}

class _HaloSearchFieldState extends State<HaloSearchField>
    with TickerProviderStateMixin {
  late AnimationController _focusController;
  late AnimationController _breathController;
  late Animation<double> _focusAnim;
  late Animation<double> _breathAnim;
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _focusAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _focusController, curve: Curves.easeOutCubic),
    );
    _breathAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _focusNode.addListener(() {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
        if (_hasFocus) {
          _focusController.forward();
          _breathController.repeat(reverse: true);
        } else {
          _focusController.reverse();
          _breathController.stop();
          _breathController.reset();
        }
      });
    });
  }

  @override
  void dispose() {
    _focusController.dispose();
    _breathController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final haloColor = widget.haloColor ?? Theme.of(context).primaryColor;

    return AnimatedBuilder(
      animation: Listenable.merge([_focusAnim, _breathAnim]),
      builder: (context, child) {
        return CustomPaint(
          painter: _HaloPainter(
            progress: _focusAnim.value,
            breath: _hasFocus ? _breathAnim.value : 1.0,
            haloColor: haloColor,
            borderRadius: widget.borderRadius,
          ),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: widget.bgColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          autofocus: widget.autoFocus,
          style: widget.textStyle,
          onSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: widget.hintStyle,
            prefixIcon: widget.prefixIcon ?? Icon(Icons.search, color: haloColor.withValues(alpha: 0.6)),
            suffixIcon: widget.suffixIcon,
            border: InputBorder.none,
            contentPadding: widget.padding,
          ),
        ),
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  final double progress;
  final double breath;
  final Color haloColor;
  final double borderRadius;

  _HaloPainter({
    required this.progress,
    required this.breath,
    required this.haloColor,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height) * breath;

    // 多层光晕
    for (int i = 0; i < 3; i++) {
      final layerProgress = (progress - i * 0.15).clamp(0.0, 1.0);
      if (layerProgress <= 0) continue;

      final radius = maxRadius * layerProgress * (0.5 + i * 0.3);
      final opacity = (1 - layerProgress) * 0.12 / (i + 1);

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            haloColor.withValues(alpha: opacity),
            haloColor.withValues(alpha: 0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(center, radius, paint);
    }

    // 边框光晕
    if (progress > 0.3) {
      final borderPaint = Paint()
        ..color = haloColor.withValues(alpha: progress * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * progress
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
        Radius.circular(borderRadius),
      );
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HaloPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.breath != breath;
}

/// 搜索页 Halo 背景装饰
class HaloSearchBackground extends StatefulWidget {
  final Widget child;
  final Color color;

  const HaloSearchBackground({
    super.key,
    required this.child,
    this.color = const Color(0xFF006241),
  });

  @override
  State<HaloSearchBackground> createState() => _HaloSearchBackgroundState();
}

class _HaloSearchBackgroundState extends State<HaloSearchBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _HaloBgPainter(
            progress: _controller.value,
            color: widget.color,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _HaloBgPainter extends CustomPainter {
  final double progress;
  final Color color;

  _HaloBgPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;

    // 两个缓慢移动的光晕圆
    for (int i = 0; i < 2; i++) {
      final phase = t + i * math.pi;
      final x = size.width * (0.3 + 0.4 * math.sin(phase));
      final y = size.height * (0.2 + 0.3 * math.cos(phase * 0.7));
      final radius = size.width * (0.25 + 0.05 * math.sin(phase * 2));

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.06),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: radius));

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HaloBgPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
