// 由 Claude 团队生成 | 移植自 v3.2 lock/view/LineIndicator.java
// 线性指示器 - 用于例句翻页指示

import 'package:flutter/material.dart';

/// 线性指示器，显示当前页码位置
class LineIndicator extends StatelessWidget {
  final int count;
  final int selectedIndex;
  final double lineHeight;
  final double lineWidth;
  final Color selectedColor;
  final Color unselectedColor;
  final double spacing;

  const LineIndicator({
    super.key,
    required this.count,
    required this.selectedIndex,
    this.lineHeight = 3.0,
    this.lineWidth = 20.0,
    this.selectedColor = Colors.white,
    this.unselectedColor = Colors.white38,
    this.spacing = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isSelected = index == selectedIndex;
        return Container(
          width: lineWidth,
          height: lineHeight,
          margin: EdgeInsets.only(right: index < count - 1 ? spacing : 0),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor : unselectedColor,
            borderRadius: BorderRadius.circular(lineHeight / 2),
          ),
        );
      }),
    );
  }
}
