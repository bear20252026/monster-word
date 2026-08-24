// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 输入相关控件：翻译自 widget/ 中的输入类
// 文件：CustomInputView, CustomSelectedView (partially covered in custom_text_widgets.dart)

import 'package:flutter/material.dart';

/// 验证码输入框（翻译自 CustomInputView.dart）
/// 显示 N 个方格，每个格子显示一个字符
class VerificationCodeInput extends StatelessWidget {
  final int length;
  final String value;
  final ValueChanged<String>? onChanged;
  final double boxSize;
  final double boxRadius;
  final Color boxColor;
  final Color textColor;
  final double fontSize;
  final bool autofocus;

  const VerificationCodeInput({
    super.key,
    this.length = 6,
    this.value = '',
    this.onChanged,
    this.boxSize = 40,
    this.boxRadius = 8,
    this.boxColor = const Color(0x40000000),
    this.textColor = Colors.black,
    this.fontSize = 24,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: boxSize,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(length, (index) {
          final char = index < value.length ? value[index] : '';
          return Container(
            width: boxSize,
            height: boxSize,
            margin: EdgeInsets.only(
              right: index < length - 1 ? (index < length - 1 ? 8.0 : 0.0) : 0,
            ),
            decoration: BoxDecoration(
              color: boxColor,
              borderRadius: BorderRadius.circular(boxRadius),
            ),
            child: Center(
              child: Text(
                char,
                style: TextStyle(
                  fontSize: fontSize,
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 带隐藏 TextField 的验证码输入包装
class VerificationCodeField extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onCompleted;
  final double boxSize;
  final double boxRadius;
  final Color boxColor;
  final Color textColor;
  final Color cursorColor;

  const VerificationCodeField({
    super.key,
    this.length = 6,
    this.onCompleted,
    this.boxSize = 40,
    this.boxRadius = 8,
    this.boxColor = const Color(0x40000000),
    this.textColor = Colors.black,
    this.cursorColor = Colors.blue,
  });

  @override
  State<VerificationCodeField> createState() => _VerificationCodeFieldState();
}

class _VerificationCodeFieldState extends State<VerificationCodeField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 可视化的方格
        IgnorePointer(
          child: VerificationCodeInput(
            length: widget.length,
            value: _controller.text,
            boxSize: widget.boxSize,
            boxRadius: widget.boxRadius,
            boxColor: widget.boxColor,
            textColor: widget.textColor,
          ),
        ),
        // 隐藏的输入框
        Opacity(
          opacity: 0,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            maxLength: widget.length,
            autofocus: true,
            onChanged: (value) {
              setState(() {});
              if (value.length == widget.length) {
                widget.onCompleted?.call(value);
              }
            },
          ),
        ),
        // 点击区域
        GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          child: Container(
            width: widget.boxSize * widget.length + 8 * (widget.length - 1),
            height: widget.boxSize,
            color: Colors.transparent,
          ),
        ),
      ],
    );
  }
}
