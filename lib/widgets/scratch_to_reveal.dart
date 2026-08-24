// Scratch to Reveal：刮刮揭示效果
// 手指/鼠标滑动擦除覆盖层，超过阈值自动完全揭示
// 颜色/阈值均可自定义
// 适用于：单词释义揭示、隐藏答案揭示、每日奖励揭示
import 'dart:math' as math;
import 'package:flutter/material.dart';

class ScratchToReveal extends StatefulWidget {
  final Widget child;           // 被遮盖的内容（揭示后显示）
  final double width;
  final double height;
  final Color? coverColor;
  final String? coverText;
  final TextStyle? coverTextStyle;
  final double revealThreshold; // 擦除面积比例阈值（0-1）
  final VoidCallback? onReveal;
  final Duration animDuration;
  final double strokeWidth;

  const ScratchToReveal({
    super.key,
    required this.child,
    this.width = 280,
    this.height = 120,
    this.coverColor,
    this.coverText,
    this.coverTextStyle,
    this.revealThreshold = 0.6,
    this.onReveal,
    this.animDuration = const Duration(milliseconds: 400),
    this.strokeWidth = 30,
  });

  @override
  State<ScratchToReveal> createState() => _ScratchToRevealState();
}

class _ScratchToRevealState extends State<ScratchToReveal>
    with SingleTickerProviderStateMixin {
  final List<Offset> _points = [];
  bool _revealed = false;
  late AnimationController _revealController;
  late Animation<double> _revealAnim;
  double _scratchedArea = 0;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: widget.animDuration,
    );
    _revealAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeOutCubic),
    );
    _revealController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onReveal?.call();
      }
    });
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_revealed) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPos = box.globalToLocal(details.globalPosition);
    setState(() {
      _points.add(localPos);
      // 估算擦除面积
      _scratchedArea = math.min(1.0, _scratchedArea + 0.002 * _points.length / 100);
    });

    if (_scratchedArea >= widget.revealThreshold) {
      _doReveal();
    }
  }

  void _doReveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
    _revealController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final coverColor = widget.coverColor ?? const Color(0xFF006241);

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: (_) {
        // 松手时如果擦除面积超过 50% 也触发揭示
        if (!_revealed && _scratchedArea > 0.4) {
          _doReveal();
        }
      },
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // 底层内容（揭示后显示）
              Positioned.fill(child: widget.child),
              // 覆盖层（擦除效果）
              AnimatedBuilder(
                animation: _revealAnim,
                builder: (context, _) {
                  final opacity = _revealAnim.value;
                  if (opacity <= 0) return const SizedBox.shrink();
                  return Positioned.fill(
                    child: CustomPaint(
                      painter: _ScratchPainter(
                        points: _points,
                        strokeWidth: widget.strokeWidth,
                        opacity: opacity,
                        color: coverColor,
                      ),
                      child: Container(
                        color: coverColor.withValues(alpha: opacity),
                        child: Center(
                          child: Opacity(
                            opacity: opacity,
                            child: widget.coverText != null
                                ? Text(
                                    widget.coverText!,
                                    style: widget.coverTextStyle ??
                                        TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  )
                                : Icon(
                                    Icons.touch_app,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    size: 32,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScratchPainter extends CustomPainter {
  final List<Offset> points;
  final double strokeWidth;
  final double opacity;
  final Color color;

  _ScratchPainter({
    required this.points,
    required this.strokeWidth,
    required this.opacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // 使用擦除混合模式
    final erasePaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // 绘制擦除路径
    for (int i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1], points[i], erasePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScratchPainter oldDelegate) =>
      oldDelegate.points.length != points.length || oldDelegate.opacity != opacity;
}

/// 简化的刮刮卡片（预设单词释义场景）
class WordScratchCard extends StatelessWidget {
  final String word;
  final String meaning;
  final Color? color;
  final double width;
  final double height;

  const WordScratchCard({
    super.key,
    required this.word,
    required this.meaning,
    this.color,
    this.width = 260,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF006241);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(word,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ScratchToReveal(
          width: width,
          height: height,
          coverColor: c,
          coverText: '👆 刮开查看释义',
          child: Container(
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              meaning,
              style: TextStyle(
                fontSize: 16,
                color: c,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
