// Scratch to Reveal：刮刮揭示效果
// 手指/鼠标滑动擦除覆盖层，超过阈值自动完全揭示
// 颜色/阈值均可自定义
// 适用于：单词释义揭示、隐藏答案揭示、每日奖励揭示
//
// v2.8.3 修复：跨词状态复用导致"第一词刮开后后续词自动揭示"的泄答案 bug。
// - [resetToken] 变化（如换词）时 didUpdateWidget 强制重置揭示状态；
// - 面积估算从"随点数加速增长"的启发式改为固定网格覆盖率（公平可刮）。
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/theme/skin_system.dart';

class ScratchToReveal extends StatefulWidget {
  final Widget child; // 被遮盖的内容（揭示后显示）
  final double width;
  final double height;
  final Color? coverColor;
  final String? coverText;
  final TextStyle? coverTextStyle;
  final double revealThreshold; // 擦除面积比例阈值（0-1）
  final VoidCallback? onReveal;
  final Duration animDuration;
  final double strokeWidth;

  /// 重置令牌：换词/换内容时传入新值，强制重新遮盖。
  /// 为空（null）时组件表现与旧版一致（不自重置，由调用方 key 保证）。
  final Object? resetToken;

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
    this.resetToken,
  });

  @override
  State<ScratchToReveal> createState() => _ScratchToRevealState();
}

class _ScratchToRevealState extends State<ScratchToReveal> with SingleTickerProviderStateMixin {
  final List<Offset> _points = [];
  bool _revealed = false;
  late AnimationController _revealController;
  late Animation<double> _revealAnim;
  double _scratchedArea = 0;
  final Set<int> _coveredCells = {};

  // 覆盖率网格：把卡面划分为固定格子，滑过的格子计入覆盖面积。
  // 相比"点数加速增长"的旧启发式，覆盖率与真实涂抹范围线性对应，手感公平。
  static const int _gridCols = 16;
  static const int _gridRows = 10;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(vsync: this, duration: widget.animDuration);
    _revealAnim = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _revealController, curve: Curves.easeOutCubic));
    _revealController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onReveal?.call();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ScratchToReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换词（resetToken 变化）→ 重新遮盖。否则第一词刮开后，
    // Element 复用会让后续词自动露出答案（泄答案 bug）。
    if (widget.resetToken != oldWidget.resetToken) {
      _resetCover();
    }
  }

  void _resetCover() {
    _revealed = false;
    _points.clear();
    _coveredCells.clear();
    _scratchedArea = 0;
    _revealController.reset();
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
      if (box.size.width > 0 && box.size.height > 0) {
        // 按笔刷半径标记覆盖格：格心落在 strokeWidth/2 内即视为已擦除，
        // 与视觉擦除范围一致，避免"看起来刮开了却不算数"。
        final cellW = box.size.width / _gridCols;
        final cellH = box.size.height / _gridRows;
        final r = widget.strokeWidth / 2;
        final colMin = ((localPos.dx - r) / cellW).floor().clamp(0, _gridCols - 1);
        final colMax = ((localPos.dx + r) / cellW).ceil().clamp(0, _gridCols - 1);
        final rowMin = ((localPos.dy - r) / cellH).floor().clamp(0, _gridRows - 1);
        final rowMax = ((localPos.dy + r) / cellH).ceil().clamp(0, _gridRows - 1);
        for (var row = rowMin; row <= rowMax; row++) {
          for (var col = colMin; col <= colMax; col++) {
            final cx = (col + 0.5) * cellW;
            final cy = (row + 0.5) * cellH;
            if (math.sqrt(math.pow(cx - localPos.dx, 2) + math.pow(cy - localPos.dy, 2)) <= r) {
              _coveredCells.add(row * _gridCols + col);
            }
          }
        }
        _scratchedArea = _coveredCells.length / (_gridCols * _gridRows);
      }
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
    final coverColor = widget.coverColor ?? context.skin.colors.accent;

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: (_) {
        // 松手时如果擦除面积超过 40% 也触发揭示
        if (!_revealed && _scratchedArea > 0.4) {
          _doReveal();
        }
      },
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.design.radius.control),
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
                                    style:
                                        widget.coverTextStyle ??
                                        TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  )
                                : Icon(Icons.touch_app, color: Colors.white.withValues(alpha: 0.7), size: 32),
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

  _ScratchPainter({required this.points, required this.strokeWidth, required this.opacity, required this.color});

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

  /// 重置令牌：换词时传入新词形，保证每词都需手动刮开（防泄答案）。
  final Object? resetToken;

  const WordScratchCard({
    super.key,
    required this.word,
    required this.meaning,
    this.color,
    this.width = 260,
    this.height = 100,
    this.resetToken,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.skin.colors.accent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(word, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ScratchToReveal(
          width: width,
          height: height,
          coverColor: c,
          resetToken: resetToken,
          // 默认提示用 touch 图标（比 emoji 更符合品牌质感）
          child: Container(
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(context.design.radius.control),
            ),
            alignment: Alignment.center,
            child: Text(
              meaning,
              style: MwTypography.bodyBold.copyWith(fontWeight: FontWeight.w600, color: c),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
