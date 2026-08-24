// 由 Claude 团队生成 | Monster Word App

// 由 Claude 团队生成 | 移植自 v3.2 widget/BBFakeSwitch.java, CustomInputView.java, MyEditText.java, AutoFitEditTextView.java, ScaleDownOnPressOnTouchListener.java
// 输入与交互类组件集合
import 'package:flutter/material.dart';
import '../theme/skin_system.dart';
import 'animations.dart';

// ─────────────────────────────────────────────────────────────
// 开关颜色常量（原版 App 使用的橙色 #E8913A）
// ─────────────────────────────────────────────────────────────
const Color kSwitchActiveColor = Color(0xFFE8913A);
const Color kSwitchInactiveColor = Color(0xFFE0E0E0);
const Color kSwitchThumbColor = Colors.white;

// ─────────────────────────────────────────────────────────────
// FakeSwitch — 自定义开关（移植自 BBFakeSwitch.java）
// ─────────────────────────────────────────────────────────────
class FakeSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final double width;
  final double height;

  const FakeSwitch({
    super.key,
    this.value = false,
    this.onChanged,
    this.enabled = true,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.width = 48,
    this.height = 28,
  });

  @override
  State<FakeSwitch> createState() => _FakeSwitchState();
}

class _FakeSwitchState extends State<FakeSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _thumbAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _thumbAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: standardCurve),
    );
    if (widget.value) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(FakeSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _controller.forward();
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
    final active = widget.activeColor ?? kSwitchActiveColor;
    final inactive = widget.inactiveColor ?? kSwitchInactiveColor;
    final thumb = widget.thumbColor ?? kSwitchThumbColor;

    return GestureDetector(
      onTap: widget.enabled
          ? () => widget.onChanged?.call(!widget.value)
          : null,
      child: AnimatedBuilder(
        animation: _thumbAnimation,
        builder: (context, _) {
          final trackColor = widget.enabled
              ? Color.lerp(inactive, active, _thumbAnimation.value)
              : inactive;
          final thumbSize = widget.height - 4;
          final thumbOffset =
              _thumbAnimation.value * (widget.width - thumbSize - 4);
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(widget.height / 2),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: thumbOffset + 2,
                  top: 2,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: thumb,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CustomInput — 自定义输入框（移植自 CustomInputView.java / MyEditText.java）
// ─────────────────────────────────────────────────────────────
class CustomInput extends StatelessWidget {
  final String? hintText;
  final String? labelText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final int maxLines;
  final bool enabled;
  final double borderRadius;

  const CustomInput({
    super.key,
    this.hintText,
    this.labelText,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onEditingComplete,
    this.maxLines = 1,
    this.enabled = true,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      maxLines: maxLines,
      enabled: enabled,
      style: TextStyle(color: skin.colors.text1),
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: skin.colors.cardBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: skin.colors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: skin.colors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: skin.colors.accent),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AutoFitInput — 自动适配字号输入框（移植自 AutoFitEditTextView.java）
// ─────────────────────────────────────────────────────────────
class AutoFitInput extends StatelessWidget {
  final String? hintText;
  final TextEditingController? controller;
  final double minFontSize;
  final double maxFontSize;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  const AutoFitInput({
    super.key,
    this.hintText,
    this.controller,
    this.minFontSize = 12,
    this.maxFontSize = 20,
    this.maxLines = 1,
    this.onChanged,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: maxFontSize),
      decoration: InputDecoration(
        hintText: hintText,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PressScale — 按压缩放效果（移植自 ScaleDownOnPressOnTouchListener.java）
// ─────────────────────────────────────────────────────────────
class PressScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration duration;
  final VoidCallback? onTap;

  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.95,
    this.duration = const Duration(milliseconds: 100),
    this.onTap,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) {
        setState(() => _pressing = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedScale(
        scale: _pressing ? widget.scale : 1.0,
        duration: widget.duration,
        child: widget.child,
      ),
    );
  }
}
