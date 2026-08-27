import 'package:flutter/material.dart';

/// Box Reveal 动画效果
/// 一个容器从指定方向展开/收缩，露出内部内容
/// 适用场景：单词详情展开、答案揭示、面板显示
class BoxReveal extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final BoxRevealDirection direction;
  final bool reveal;
  final Curve curve;

  const BoxReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.direction = BoxRevealDirection.bottom,
    this.reveal = true,
    this.curve = Curves.easeOut,
  });

  @override
  State<BoxReveal> createState() => _BoxRevealState();
}

enum BoxRevealDirection { top, bottom, left, right }

class _BoxRevealState extends State<BoxReveal> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _sizeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    if (widget.reveal) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didUpdateWidget(BoxReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reveal != oldWidget.reveal) {
      if (widget.reveal) {
        Future.delayed(widget.delay, () {
          if (mounted) _controller.forward();
        });
      } else {
        _controller.reverse();
      }
    }
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
      // 预构建子树：动画每帧只重建裁剪/透明包装层，不重建 child
      child: widget.child,
      builder: (context, child) {
        return ClipRect(
          child: Align(
            alignment: _getAlignment(),
            heightFactor: widget.direction == BoxRevealDirection.left || widget.direction == BoxRevealDirection.right
                ? 1.0
                : _sizeAnimation.value,
            widthFactor: widget.direction == BoxRevealDirection.left || widget.direction == BoxRevealDirection.right
                ? _sizeAnimation.value
                : 1.0,
            child: Opacity(opacity: _opacityAnimation.value.clamp(0.0, 1.0), child: child),
          ),
        );
      },
    );
  }

  Alignment _getAlignment() {
    switch (widget.direction) {
      case BoxRevealDirection.top:
        return Alignment.bottomCenter;
      case BoxRevealDirection.bottom:
        return Alignment.topCenter;
      case BoxRevealDirection.left:
        return Alignment.centerRight;
      case BoxRevealDirection.right:
        return Alignment.centerLeft;
    }
  }
}

/// Flip Card 翻转卡片效果
/// 点击翻转卡片，显示背面内容
/// 适用场景：单词学习（正面=单词，背面=释义+例句）
class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final Duration duration;
  final VoidCallback? onTap;
  final bool flipOnTap;

  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 400),
    this.onTap,
    this.flipOnTap = true,
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (widget.onTap != null) widget.onTap!();
    if (!widget.flipOnTap) return;

    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final isShowingFront = _animation.value < 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_animation.value * 3.14159),
            child: isShowingFront
                ? widget.front
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(3.14159),
                    child: widget.back,
                  ),
          );
        },
      ),
    );
  }
}
