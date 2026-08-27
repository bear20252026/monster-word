// 文字揭示卡片：悬停/点击时揭示隐藏文字
// 适用于：每日一句、统计卡片、提示信息
import 'package:flutter/material.dart';

class TextRevealCard extends StatefulWidget {
  final String title;
  final String revealText;
  final Widget? icon;
  final TextStyle? titleStyle;
  final TextStyle? revealStyle;
  final Color? bgColor;
  final Color? revealBgColor;
  final EdgeInsets padding;
  final double borderRadius;
  final Duration duration;
  final VoidCallback? onTap;

  const TextRevealCard({
    super.key,
    required this.title,
    required this.revealText,
    this.icon,
    this.titleStyle,
    this.revealStyle,
    this.bgColor,
    this.revealBgColor,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 16,
    this.duration = const Duration(milliseconds: 400),
    this.onTap,
  });

  @override
  State<TextRevealCard> createState() => _TextRevealCardState();
}

class _TextRevealCardState extends State<TextRevealCard> with SingleTickerProviderStateMixin {
  bool _revealed = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _revealed = !_revealed;
      if (_revealed) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: widget.duration,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _revealed ? (widget.revealBgColor ?? widget.bgColor) : widget.bgColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: _revealed ? 20 : 8,
              offset: Offset(0, _revealed ? 8 : 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (widget.icon != null) ...[widget.icon!, const SizedBox(width: 12)],
                Expanded(child: Text(widget.title, style: widget.titleStyle)),
                AnimatedRotation(
                  turns: _revealed ? 0.5 : 0,
                  duration: widget.duration,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: widget.titleStyle?.color?.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(widget.revealText, style: widget.revealStyle),
                  ),
                ),
              ),
              crossFadeState: _revealed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: widget.duration,
            ),
          ],
        ),
      ),
    );
  }
}
