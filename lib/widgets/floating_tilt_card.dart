// lib/widgets/floating_tilt_card.dart
// 桌面悬浮卡（设计语言参考：Inspira UI FloatingCard 的指针 3D 倾斜与眩光、
// Apple 卡片廊的光影层次、Holo Card Studio 的随视角移动的全息光带）。
//
// 鼠标悬停时卡片朝指针方向微倾（透视变换）+ 抬升 + 阴影加深，指针处有
// 径向眩光，另有一道随指针横移的微光带；移出后回落。触屏没有 hover，
// 表现与静止卡一致。视觉量按 docs/motion_spec.md 克制原则压低：
// 倾角默认 8°、抬升 6px、放大 1.03、眩光峰值 0.20，反馈 ≤ MotionDurations.base。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/motion_tokens.dart';

/// 指针跟随的 3D 悬浮卡容器。
///
/// [borderRadius] 用于阴影形状与眩光裁切，应与子内容的封面圆角一致。
/// [cursor] 供可点卡片给桌面鼠标以可点暗示（如 SystemMouseCursors.click）。
class FloatingTiltCard extends StatefulWidget {
  const FloatingTiltCard({
    super.key,
    required this.child,
    this.borderRadius,
    this.maxTilt = 0.14,
    this.lift = 6,
    this.hoverScale = 1.03,
    this.glareOpacity = 0.20,
    this.cursor,
  });

  final Widget child;
  final BorderRadius? borderRadius;

  /// 最大倾角（弧度），指针在卡片边缘时达到。
  final double maxTilt;

  /// 悬停抬升距离（px）。
  final double lift;

  /// 悬停放大倍数。
  final double hoverScale;

  /// 眩光峰值不透明度。
  final double glareOpacity;

  final MouseCursor? cursor;

  @override
  State<FloatingTiltCard> createState() => _FloatingTiltCardState();
}

class _FloatingTiltCardState extends State<FloatingTiltCard> {
  bool _hovering = false;

  /// 归一化指针位置（-1..1，中心为 0，左上为负）。
  Offset _pointer = Offset.zero;

  void _onHover(PointerHoverEvent event) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size == Size.zero) return;
    final local = box.globalToLocal(event.position);
    setState(() {
      _hovering = true;
      _pointer = Offset((local.dx / box.size.width - 0.5) * 2, (local.dy / box.size.height - 0.5) * 2);
      _pointer = Offset(_pointer.dx.clamp(-1.0, 1.0), _pointer.dy.clamp(-1.0, 1.0));
    });
  }

  void _onExit(PointerExitEvent event) {
    setState(() {
      _hovering = false;
      _pointer = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 无障碍：系统开启「减弱动态效果」时撤掉指针动效，仅保留可点光标。
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return MouseRegion(cursor: widget.cursor ?? MouseCursor.defer, child: widget.child);
    }

    final br = widget.borderRadius ?? BorderRadius.zero;

    return MouseRegion(
      cursor: widget.cursor ?? MouseCursor.defer,
      onHover: _onHover,
      onExit: _onExit,
      // 指针追逐：150ms 缓动逼近目标位置，让倾斜与眩光丝滑跟手。
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(end: _pointer),
        duration: MotionDurations.fast,
        curve: MotionCurves.standard,
        builder: (context, pointer, _) {
          // 悬停进度：0 → 1（进入）或 1 → 0（离开），驱动抬升/倾斜幅度。
          return TweenAnimationBuilder<double>(
            tween: Tween(end: _hovering ? 1.0 : 0.0),
            duration: MotionDurations.base,
            curve: MotionCurves.standard,
            builder: (context, hover, _) {
              final scale = 1 + (widget.hoverScale - 1) * hover;
              final matrix = Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateX(-pointer.dy * widget.maxTilt * hover)
                ..rotateY(pointer.dx * widget.maxTilt * hover)
                ..scaleByDouble(scale, scale, scale, 1.0)
                ..translateByDouble(0.0, -widget.lift * hover, 0.0, 1.0);
              return Transform(
                alignment: Alignment.center,
                transform: matrix,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: br,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black12.withValues(alpha: AppColors.black12.a * (1 + 1.6 * hover)),
                        blurRadius: 10 + 14 * hover,
                        offset: Offset(0, 3 + 7 * hover),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: br,
                    child: Stack(
                      children: [
                        widget.child,
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Opacity(
                              // 径向眩光：跟随指针的高光（FloatingCard 的 glare）。
                              opacity: widget.glareOpacity * hover,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment(pointer.dx, pointer.dy),
                                    radius: 0.9,
                                    colors: [
                                      AppColors.white100.withValues(alpha: 0.75),
                                      AppColors.white100.withValues(alpha: 0.15),
                                      AppColors.white100.withValues(alpha: 0),
                                    ],
                                    stops: const [0, 0.45, 1],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Opacity(
                              // 全息光带：一道随指针横移的斜向微光（Holo Card 光泽语言）。
                              opacity: 0.14 * hover,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment(-1 + pointer.dx * 2, -1.2),
                                    end: Alignment(pointer.dx * 2, 1.2),
                                    colors: [
                                      AppColors.white100.withValues(alpha: 0),
                                      AppColors.white100.withValues(alpha: 0.5),
                                      AppColors.white100.withValues(alpha: 0),
                                    ],
                                    stops: const [0.42, 0.5, 0.58],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
