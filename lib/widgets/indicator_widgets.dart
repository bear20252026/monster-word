// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 指示器控件：翻译自 widget/ 中的指示器类
// 文件：DotIndicator, SquareIndicator, CircleIndicator, PageNumView

import 'package:flutter/material.dart';
import 'animations.dart';

/// 圆点指示器（翻译自 DotIndicator.dart）
class DotIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final double dotRadius;
  final double gap;
  final Color normalColor;
  final Color activeColor;

  const DotIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    this.dotRadius = 4.0,
    this.gap = 8.0,
    this.normalColor = const Color(0x12000000),
    this.activeColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isActive = index <= currentIndex;
        return Container(
          width: dotRadius * 2,
          height: dotRadius * 2,
          margin: EdgeInsets.symmetric(horizontal: gap / 2),
          decoration: BoxDecoration(
            color: isActive ? activeColor : normalColor,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

/// 方形指示器（翻译自 SquareIndicator.dart）
class SquareIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final double normalSize;
  final double selectedSize;
  final double gap;
  final Color normalColor;
  final Color selectedColor;

  const SquareIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    this.normalSize = 4.0,
    this.selectedSize = 6.0,
    this.gap = 6.0,
    this.normalColor = const Color(0x8AFFFFFF),
    this.selectedColor = const Color(0xDEFFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isSelected = index == currentIndex;
        final size = isSelected ? selectedSize : normalSize;
        return Container(
          width: size,
          height: size,
          margin: EdgeInsets.symmetric(horizontal: gap / 2),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor : normalColor,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

/// 圆形指示器（翻译自 CircleIndicator.dart）
class CircleIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final double size;
  final Color normalColor;
  final Color activeColor;
  final Color passedColor;

  const CircleIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    this.size = 10.0,
    this.normalColor = const Color(0x12000000),
    this.activeColor = Colors.blue,
    this.passedColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        Color color;
        if (index == currentIndex) {
          color = activeColor;
        } else if (index < currentIndex) {
          color = passedColor;
        } else {
          color = normalColor;
        }
        return Container(
          width: size,
          height: size,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

/// 页码视图（翻译自 PageNumView.dart）
/// 带滑动光标的页码指示器
class PageNumIndicator extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final double cursorWidth;
  final Color cursorColor;
  final Color backgroundColor;

  const PageNumIndicator({
    super.key,
    required this.totalPages,
    required this.currentPage,
    this.cursorWidth = 4.0,
    this.cursorColor = Colors.blue,
    this.backgroundColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages == 0) return const SizedBox.shrink();
    final itemWidth = 1.0 / totalPages;
    return SizedBox(
      height: cursorWidth * 2,
      child: Stack(
        children: [
          // 背景
          Container(color: backgroundColor),
          // 光标
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: standardCurve,
            left: currentPage * itemWidth * MediaQuery.of(context).size.width,
            top: 0,
            bottom: 0,
            width: itemWidth * MediaQuery.of(context).size.width,
            child: Container(
              decoration: BoxDecoration(
                color: cursorColor,
                borderRadius: BorderRadius.circular(cursorWidth),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
