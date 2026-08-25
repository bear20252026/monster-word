// 呼吸文字效果 — 文字随时间做平滑的缩放/透明度波动，模拟呼吸节奏
// 灵感来源：inspira-ui breathing-text
// 适用场景：首页CTA按钮、重点单词高亮、奖励数字、加载提示
import 'package:flutter/material.dart';

/// 呼吸文字组件
///
/// 通过正弦波动让文字产生「呼吸」般的节奏感，吸引用户注意力。
/// 支持自定义呼吸周期、缩放范围、透明度范围。
class BreathingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final double minScale;
  final double maxScale;
  final double minOpacity;
  final double maxOpacity;
  final bool enableScale;
  final bool enableOpacity;
  final bool repeat;

  const BreathingText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 2000),
    this.minScale = 0.96,
    this.maxScale = 1.04,
    this.minOpacity = 0.7,
    this.maxOpacity = 1.0,
    this.enableScale = true,
    this.enableOpacity = true,
    this.repeat = true,
  });

  @override
  State<BreathingText> createState() => _BreathingTextState();
}

class _BreathingTextState extends State<BreathingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // 使用 easeInOutSine 曲线模拟自然呼吸节奏
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    if (widget.repeat) {
      _controller.repeat(reverse: true);
    } else {
      _controller.forward();
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
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;
        final scale = widget.enableScale
            ? widget.minScale + (widget.maxScale - widget.minScale) * value
            : 1.0;
        final opacity = widget.enableOpacity
            ? widget.minOpacity +
                (widget.maxOpacity - widget.minOpacity) * value
            : 1.0;

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Text(
              widget.text,
              style: widget.style,
            ),
          ),
        );
      },
    );
  }
}

/// 呼吸文字构建器 — 对多个字符分别施加错峰呼吸效果
/// 每个字符的呼吸相位不同，形成波浪式「呼吸」
class BreathingTextWave extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final double minScale;
  final double maxScale;
  final double phaseStep; // 每个字符之间的相位差（0~1）

  const BreathingTextWave({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 2500),
    this.minScale = 0.95,
    this.maxScale = 1.05,
    this.phaseStep = 0.15,
  });

  @override
  State<BreathingTextWave> createState() => _BreathingTextWaveState();
}

class _BreathingTextWaveState extends State<BreathingTextWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
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
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.text.length, (i) {
            final char = widget.text[i];
            if (char == ' ') return const SizedBox(width: 6);

            // 每个字符相位错开
            final phase = i * widget.phaseStep;
            final t = (_controller.value + phase) % 1.0;
            // 正弦波动
            final wave = (1 + (t * 2 - 1).abs() * -1) * 0.5 + 0.5;
            final scale =
                widget.minScale + (widget.maxScale - widget.minScale) * wave;

            return Transform.scale(
              scale: scale,
              child: Text(char, style: widget.style),
            );
          }),
        );
      },
    );
  }
}
