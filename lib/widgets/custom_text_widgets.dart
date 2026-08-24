// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 文本相关控件：翻译自 widget/ 中的文本类
// 文件：MyTextView, MyEditText, MyAnimatedNumTextView, CustomeTypefaceSpan, TextViewUtils, CustomSelectedView

import 'package:flutter/material.dart';
import 'animations.dart';

/// 自定义字体文本（翻译自 MyTextView.java）
/// 支持 phonetic / han_medium / soleil_regular / soleil_bold 四种字体
class MyCustomText extends StatelessWidget {
  final String text;
  final String? fontFamily;
  final double? fontSize;
  final Color? color;
  final FontWeight? fontWeight;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool showShadow;

  const MyCustomText(
    this.text, {
    super.key,
    this.fontFamily,
    this.fontSize,
    this.color,
    this.fontWeight,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        shadows: showShadow
            ? [
                Shadow(
                  color: color ?? Colors.black,
                  blurRadius: 20,
                ),
              ]
            : null,
      ),
    );
  }
}

/// 自定义输入框（翻译自 MyEditText.dart）
/// 支持自定义字体和光标颜色
class MyCustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? fontFamily;
  final Color? cursorColor;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final InputDecoration? decoration;

  const MyCustomTextField({
    super.key,
    this.controller,
    this.hintText,
    this.fontFamily,
    this.cursorColor,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.maxLength,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      maxLength: maxLength,
      style: TextStyle(fontFamily: fontFamily),
      cursorColor: cursorColor,
      decoration: decoration ??
          InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
            counterText: '',
          ),
    );
  }
}

/// 数字动画文本（翻译自 MyAnimatedNumTextView.dart）
/// 数字变化时自动播放滚动动画
class AnimatedNumText extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;

  const AnimatedNumText({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedNumText> createState() => _AnimatedNumTextState();
}

class _AnimatedNumTextState extends State<AnimatedNumText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;
  int _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _oldValue = widget.value;
    _animation = IntTween(begin: _oldValue, end: widget.value)
        .animate(CurvedAnimation(parent: _controller, curve: fataleCurve));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedNumText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
      _animation = IntTween(begin: _oldValue, end: widget.value)
          .animate(CurvedAnimation(parent: _controller, curve: fataleCurve));
      _controller.reset();
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
        return Text(
          _animation.value.toString(),
          style: widget.style,
        );
      },
    );
  }
}

/// 自定义字体 Span 工具（翻译自 CustomeTypefaceSpan.dart）
/// 用于 RichText 中指定部分文本使用不同字体
class CustomFontTextSpan extends TextSpan {
  final String? fontFamily;

  const CustomFontTextSpan({
    required String super.text,
    this.fontFamily,
    super.style,
    super.children,
    super.recognizer,
  });
}

/// 文本工具类（翻译自 TextViewUtils.dart）
class TextViewUtils {
  /// 设置文本样式
  static TextStyle setTextStyle({
    String? fontFamily,
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }

  /// 创建可点击的图片 Widget（替代 ClickableImageSpan）
  static Widget buildClickableImage({
    required Widget image,
    VoidCallback? onTap,
    Alignment alignment = Alignment.center,
  }) {
    return GestureDetector(onTap: onTap, child: image);
  }
}

/// 可选中文本视图（翻译自 CustomSelectedView.dart）
/// 点击单词自动选中并触发回调
class SelectableWordText extends StatefulWidget {
  final String text;
  final ValueChanged<String>? onWordSelected;
  final TextStyle? style;
  final Color? highlightColor;

  const SelectableWordText({
    super.key,
    required this.text,
    this.onWordSelected,
    this.style,
    this.highlightColor,
  });

  @override
  State<SelectableWordText> createState() => _SelectableWordTextState();
}

class _SelectableWordTextState extends State<SelectableWordText> {
  String _selectedWord = '';

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      widget.text,
      style: widget.style,
      onSelectionChanged: (selection, cause) {
        if (selection.isCollapsed) return;
        final word = widget.text
            .substring(selection.start, selection.end)
            .trim();
        if (word.isNotEmpty && word != _selectedWord) {
          _selectedWord = word;
          widget.onWordSelected?.call(word);
        }
      },
    );
  }
}
