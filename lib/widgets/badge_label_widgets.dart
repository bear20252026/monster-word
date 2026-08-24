// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 角标/标签控件：翻译自 widget/ 中的角标和标签类
// 文件：MyBadgeView, ThirdPartIconView, TipLabelDynamicView, LableClassifyView

import 'package:flutter/material.dart';

/// 角标视图（翻译自 MyBadgeView.dart）
/// 用于显示未读数量等
class BadgeView extends StatelessWidget {
  final int count;
  final Color bgColor;
  final Color textColor;
  final double fontSize;
  final double? height;

  const BadgeView({
    super.key,
    required this.count,
    this.bgColor = const Color(0xFFFF5253),
    this.textColor = Colors.white,
    this.fontSize = 12,
    this.height,
  });

  String _getDisplayText() {
    if (count <= 0) return '';
    return count > 99 ? '99+' : count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final text = _getDisplayText();
    if (text.isEmpty) return const SizedBox.shrink();
    final h = height ?? 20;
    final w = text.length > 2 ? h * 1.44 : h;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(h / 2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 第三方图标容器（翻译自 ThirdPartIconView.dart）
/// 简单的图标容器，用于显示第三方登录图标等
class ThirdPartyIconContainer extends StatelessWidget {
  final Widget icon;
  final double size;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const ThirdPartyIconContainer({
    super.key,
    required this.icon,
    this.size = 44,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Center(child: icon),
      ),
    );
  }
}

/// 动态提示标签（翻译自 TipLabelDynamicView.dart）
/// 带箭头和动画的提示标签
class AnimatedTipLabel extends StatefulWidget {
  final String text;
  final TipArrowDirection arrowDirection;
  final double slideDistance;
  final TextStyle? textStyle;

  const AnimatedTipLabel({
    super.key,
    required this.text,
    this.arrowDirection = TipArrowDirection.left,
    this.slideDistance = 20.0,
    this.textStyle,
  });

  @override
  State<AnimatedTipLabel> createState() => _AnimatedTipLabelState();
}

enum TipArrowDirection { left, up, down, downShort }

class _AnimatedTipLabelState extends State<AnimatedTipLabel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _arrowAlpha;
  late Animation<Offset> _arrowSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _arrowAlpha = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 30),
    ]).animate(_controller);
    _arrowSlide = Tween<Offset>(
      begin: Offset.zero,
      end: _getSlideOffset(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
    _controller.repeat();
  }

  Offset _getSlideOffset() {
    switch (widget.arrowDirection) {
      case TipArrowDirection.left:
        return Offset(-widget.slideDistance, 0);
      case TipArrowDirection.up:
        return Offset(0, -widget.slideDistance);
      case TipArrowDirection.down:
      case TipArrowDirection.downShort:
        return Offset(0, widget.slideDistance);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SlideTransition(
          position: _arrowSlide,
          child: FadeTransition(
            opacity: _arrowAlpha,
            child: Icon(
              _getArrowIcon(),
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          widget.text,
          style: widget.textStyle ??
              const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }

  IconData _getArrowIcon() {
    switch (widget.arrowDirection) {
      case TipArrowDirection.left:
        return Icons.arrow_back;
      case TipArrowDirection.up:
        return Icons.arrow_upward;
      case TipArrowDirection.down:
      case TipArrowDirection.downShort:
        return Icons.arrow_downward;
    }
  }
}

/// 标签分类视图（翻译自 LableClassifyView.dart）
/// 自动换行的标签选择器
class TagClassifyView extends StatelessWidget {
  final List<String> tags;
  final String? selectedTag;
  final ValueChanged<String>? onTagSelected;
  final Color selectedColor;
  final Color normalColor;
  final Color selectedTextColor;
  final Color normalTextColor;
  final double tagHeight;
  final double tagWidth;
  final double tagRadius;
  final double minSpacing;

  const TagClassifyView({
    super.key,
    required this.tags,
    this.selectedTag,
    this.onTagSelected,
    this.selectedColor = Colors.blue,
    this.normalColor = const Color(0x08000000),
    this.selectedTextColor = Colors.white,
    this.normalTextColor = const Color(0x8A000000),
    this.tagHeight = 36,
    this.tagWidth = 80,
    this.tagRadius = 18,
    this.minSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: minSpacing,
      runSpacing: 8,
      children: tags.map((tag) {
        final isSelected = tag == selectedTag;
        return GestureDetector(
          onTap: () => onTagSelected?.call(tag),
          child: Container(
            width: tagWidth,
            height: tagHeight,
            decoration: BoxDecoration(
              color: isSelected ? selectedColor : null,
              borderRadius: BorderRadius.circular(tagRadius),
              border: isSelected
                  ? null
                  : Border.all(color: normalColor, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              tag,
              style: TextStyle(
                color: isSelected ? selectedTextColor : normalTextColor,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
