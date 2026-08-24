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

class _TextGenerateEffectState extends State<TextGenerateEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _characterCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _characterCount = StepTween(begin: 0, end: widget.text.length).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

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
        return Text(
          displayText,
          style: widget.style,
        );
      },
    );
  }
}

/// 多行文字逐字浮现效果（带淡入）
/// 每行文字依次浮现，每行内部字符逐字显示
class TextGenerateEffectMultiLine extends StatefulWidget {
  final List<String> lines;
  final TextStyle? style;
  final Duration lineDelay;
  final Duration charDuration;

  const TextGenerateEffectMultiLine({
    super.key,
    required this.lines,
    this.style,
    this.lineDelay = const Duration(milliseconds: 400),
    this.charDuration = const Duration(milliseconds: 30),
  });

  @override
  State<TextGenerateEffectMultiLine> createState() =>
      _TextGenerateEffectMultiLineState();
}

class _TextGenerateEffectMultiLineState extends State<TextGenerateEffectMultiLine>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<int>> _characterCounts = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.lines.length; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: widget.lines[i].length * widget.charDuration.inMilliseconds,
        ),
      );
      _controllers.add(controller);
      _characterCounts.add(
        StepTween(begin: 0, end: widget.lines[i].length).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOut),
        ),
      );
    }

    // 依次启动每行动画
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(
        milliseconds: i * widget.lineDelay.inMilliseconds,
      ), () {
        if (mounted) {
          _controllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(widget.lines.length, (i) {
        return AnimatedBuilder(
          animation: _characterCounts[i],
          builder: (context, child) {
            final visibleCount = _characterCounts[i].value.clamp(0, widget.lines[i].length);
            final displayText = widget.lines[i].substring(0, visibleCount);
            return Text(
              displayText,
              style: widget.style,
            );
          },
        );
      }),
    );
  }
}
