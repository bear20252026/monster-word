// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 布局控件：翻译自 widget/ 中的布局类
// 文件：ShadowLinearLayout, NewLinearLayout, SwipeLinearLayout, DragDownFrameLayout, SimpleSlidingDownView

import 'package:flutter/material.dart';
import '../tokens/design_tokens.dart';
import 'animations.dart';

/// 阴影线性布局（翻译自 ShadowLinearLayout.dart）
class ShadowContainer extends StatelessWidget {
  final Widget child;
  final Color shadowColor;
  final Color bgColor;
  final double shadowRadius;
  final double shadowOffsetY;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ShadowContainer({
    super.key,
    required this.child,
    this.shadowColor = MistralColors.black26,
    this.bgColor = AppColors.white100,
    this.shadowRadius = 4.0,
    this.shadowOffsetY = 2.0,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? EdgeInsets.only(
        bottom: shadowOffsetY.abs() + shadowRadius,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: shadowRadius,
            offset: Offset(0, shadowOffsetY),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 可滑动线性布局（翻译自 SwipeLinearLayout.dart）
/// 支持左右滑动手势
class SwipeableContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onTap;
  final double swipeThreshold;

  const SwipeableContainer({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onTap,
    this.swipeThreshold = 200.0,
  });

  @override
  State<SwipeableContainer> createState() => _SwipeableContainerState();
}

class _SwipeableContainerState extends State<SwipeableContainer> {
  double _startX = 0;
  double _startY = 0;
  bool _isSwipe = false;
  bool _isTap = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        _startX = details.localPosition.dx;
        _startY = details.localPosition.dy;
        _isSwipe = false;
        _isTap = true;
      },
      onHorizontalDragUpdate: (details) {
        if (!_isSwipe) {
          final dx = (details.localPosition.dx - _startX).abs();
          final dy = (details.localPosition.dy - _startY).abs();
          if (dx > dy && dx > 10) {
            _isSwipe = true;
            _isTap = false;
          }
        }
      },
      onHorizontalDragEnd: (details) {
        if (_isSwipe) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -widget.swipeThreshold) {
            widget.onSwipeLeft?.call();
          } else if (velocity > widget.swipeThreshold) {
            widget.onSwipeRight?.call();
          }
        }
      },
      onTap: _isTap ? widget.onTap : null,
      child: widget.child,
    );
  }
}

/// 下拉拖拽容器（翻译自 DragDownFrameLayout.dart）
/// 下拉超过阈值触发回调（如关闭页面）
class DragDownContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onOverMax;
  final double maxDrag;
  final double threshold;

  const DragDownContainer({
    super.key,
    required this.child,
    this.onOverMax,
    this.maxDrag = 180.0,
    this.threshold = 0.3,
  });

  @override
  State<DragDownContainer> createState() => _DragDownContainerState();
}

class _DragDownContainerState extends State<DragDownContainer>
    with SingleTickerProviderStateMixin {
  double _translateY = 0;
  double _startY = 0;
  bool _dragging = false;
  late AnimationController _resetController;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 195),
    );
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _resetPosition() {
    final anim = Tween<double>(begin: _translateY, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: SpringCurve()),
    );
    _resetController.forward(from: 0);
    anim.addListener(() {
      if (mounted) setState(() => _translateY = anim.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: (details) {
        _startY = details.globalPosition.dy;
        _dragging = false;
      },
      onVerticalDragUpdate: (details) {
        final dy = details.globalPosition.dy - _startY;
        if (dy > 0) {
          _dragging = true;
          final fraction = (dy / widget.maxDrag).clamp(0.0, 1.0);
          setState(() {
            _translateY = widget.maxDrag * fraction * 0.3;
          });
        }
      },
      onVerticalDragEnd: (details) {
        if (_dragging) {
          final dy = details.globalPosition.dy - _startY;
          if (dy > widget.maxDrag * widget.threshold) {
            widget.onOverMax?.call();
          } else {
            _resetPosition();
          }
        }
      },
      child: Transform.translate(
        offset: Offset(0, _translateY),
        child: widget.child,
      ),
    );
  }
}

/// 简单下拉视图（翻译自 SimpleSlidingDownView.dart）
/// 支持下拉滑动关闭
class SlidingDownDismissView extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDismissed;
  final double dismissThreshold;

  const SlidingDownDismissView({
    super.key,
    required this.child,
    this.onDismissed,
    this.dismissThreshold = 0.5,
  });

  @override
  State<SlidingDownDismissView> createState() => _SlidingDownDismissViewState();
}

class _SlidingDownDismissViewState extends State<SlidingDownDismissView>
    with SingleTickerProviderStateMixin {
  double _translateY = 0;
  double _startY = 0;
  bool _isDragging = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: (details) {
        _startY = details.globalPosition.dy;
        _isDragging = false;
      },
      onVerticalDragUpdate: (details) {
        final dy = details.globalPosition.dy - _startY;
        if (!_isDragging && dy > 10) {
          _isDragging = true;
        }
        if (_isDragging && dy > 0) {
          setState(() => _translateY = dy);
        }
      },
      onVerticalDragEnd: (details) {
        if (!_isDragging) return;
        final screenHeight = MediaQuery.of(context).size.height;
        if (_translateY > screenHeight * widget.dismissThreshold) {
          // dismiss
          final anim = Tween<double>(begin: _translateY, end: screenHeight)
              .animate(CurvedAnimation(parent: _animController, curve: standardCurve));
          _animController.forward(from: 0);
          anim.addListener(() {
            setState(() => _translateY = anim.value);
          });
          _animController.addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              widget.onDismissed?.call();
            }
          });
        } else {
          // reset
          final anim = Tween<double>(begin: _translateY, end: 0)
              .animate(CurvedAnimation(parent: _animController, curve: standardCurve));
          _animController.forward(from: 0);
          anim.addListener(() {
            setState(() => _translateY = anim.value);
          });
        }
      },
      child: Transform.translate(
        offset: Offset(0, _translateY),
        child: widget.child,
      ),
    );
  }
}
