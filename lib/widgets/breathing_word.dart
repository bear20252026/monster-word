// BreathingWord：单单词呼吸动画（Flutter 版，参考 Inspira UI breathing-text）
// 同一时刻屏幕上只显示一个单词；单词的每个字母做渐强渐弱的"呼吸"
// （透明度+微缩放），字母间错峰产生波浪节奏；词与词之间淡入淡出轮换。
// 取代此前 PathMarquee 的波浪滚动文字（整串字符糊成一片的"重影"效果）。
import 'package:flutter/material.dart';

class BreathingWord extends StatefulWidget {
  /// 轮换显示的单词列表；同一时刻只渲染其中一个。
  final List<String> words;

  final TextStyle? style;

  /// 单个单词停留时长（含呼吸若干轮）。
  final Duration perWord;

  /// 词与词切换的淡入淡出时长。
  final Duration crossfade;

  /// 呼吸谷值透明度（峰值恒为 1.0）。
  final double minOpacity;

  const BreathingWord({
    super.key,
    required this.words,
    this.style,
    this.perWord = const Duration(seconds: 3),
    this.crossfade = const Duration(milliseconds: 500),
    this.minOpacity = 0.35,
  });

  @override
  State<BreathingWord> createState() => _BreathingWordState();
}

class _BreathingWordState extends State<BreathingWord> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.perWord)
      ..addStatusListener(_onStatus)
      ..forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted) return;
    setState(() => _index = (_index + 1) % widget.words.length);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    return AnimatedSwitcher(
      duration: widget.crossfade,
      child: KeyedSubtree(
        key: ValueKey(_index),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final word = widget.words[_index];
            final t = _controller.value;
            final stagger = 1.0 / (word.length + 1);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < word.length; i++)
                  if (word[i] == ' ')
                    SizedBox(width: (style.fontSize ?? 14) * 0.35)
                  else
                    _buildLetter(word[i], t, i * stagger, style),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 单个字母：三角波 + easeInOut 形成"吸气—呼气"节奏，错峰呈现波浪感。
  Widget _buildLetter(String ch, double t, double phase, TextStyle style) {
    final tri = (t * 2 + phase) % 2;
    final raw = tri < 1 ? tri : 2 - tri;
    final breathe = Curves.easeInOut.transform(raw);
    return Opacity(
      opacity: widget.minOpacity + (1 - widget.minOpacity) * breathe,
      child: Transform.scale(
        scale: 0.97 + 0.05 * breathe,
        child: Text(ch, style: style),
      ),
    );
  }
}
