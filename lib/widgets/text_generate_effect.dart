import 'package:flutter/material.dart';

/// 文字逐字浮现效果（打字机动画）
/// 让文字一个一个字符地显示，营造生动的浮现效果
class TextGenerateEffect extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final Duration delay;
  final bool animateOnVisible;

  const TextGenerateEffect({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.delay = const Duration(milliseconds: 200),
    this.animateOnVisible = false,
  });

  @override
  State<TextGenerateEffect> createState() => _TextGenerateEffectState();
}

class _TextGenerateEffectState extends State<TextGenerateEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _characterCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _characterCount = StepTween(
      begin: 0,
      end: widget.text.length,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // 延迟后开始动画
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _characterCount,
      builder: (context, child) {
        final visibleCount = _characterCount.value.clamp(0, widget.text.length);
        final displayText = widget.text.substring(0, visibleCount);
        return Text(displayText, style: widget.style);
      },
    );
  }
}
