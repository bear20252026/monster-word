// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 头部/导航控件：翻译自 widget/ 中的头部类
// 文件：CustomHeadView, SegmentedGroup, SlideBar

import 'package:flutter/material.dart';
import '../tokens/design_tokens.dart';

/// 自定义头部栏（翻译自 CustomHeadView.dart）
/// 支持左右按钮、标题、双标题切换
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leftButton;
  final Widget? rightButton;
  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;
  final Color? backgroundColor;
  final bool showTwoTitles;
  final String? leftTitle;
  final String? rightTitle;
  final int currentTitleIndex;
  final ValueChanged<int>? onTitleChanged;

  const CustomAppBar({
    super.key,
    this.title = '',
    this.leftButton,
    this.rightButton,
    this.onLeftTap,
    this.onRightTap,
    this.backgroundColor,
    this.showTwoTitles = false,
    this.leftTitle,
    this.rightTitle,
    this.currentTitleIndex = 0,
    this.onTitleChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      leading: leftButton != null
          ? GestureDetector(onTap: onLeftTap, child: leftButton)
          : null,
      title: showTwoTitles
          ? _buildTwoTitleSelector()
          : Text(title, style: const TextStyle(fontSize: 18)),
      centerTitle: true,
      actions: [
        if (rightButton != null)
          GestureDetector(onTap: onRightTap, child: rightButton!),
      ],
    );
  }

  Widget _buildTwoTitleSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTitleItem(leftTitle ?? '', 0),
        const SizedBox(width: 20),
        _buildTitleItem(rightTitle ?? '', 1),
      ],
    );
  }

  Widget _buildTitleItem(String text, int index) {
    final isSelected = index == currentTitleIndex;
    return GestureDetector(
      onTap: () => onTitleChanged?.call(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? MistralColors.ink : MistralColors.slate,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 20 : 0,
            height: 2,
            decoration: BoxDecoration(
              color: isSelected ? MistralColors.info : Colors.transparent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分段选择器（翻译自 SegmentedGroup.dart）
/// 类似 iOS 的 UISegmentedControl
class SegmentedSelector extends StatelessWidget {
  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int>? onChanged;
  final Color selectedColor;
  final Color unselectedColor;
  final Color selectedTextColor;
  final Color unselectedTextColor;

  const SegmentedSelector({
    super.key,
    required this.segments,
    required this.selectedIndex,
    this.onChanged,
    this.selectedColor = MistralColors.info,
    this.unselectedColor = Colors.transparent,
    this.selectedTextColor = AppColors.white100,
    this.unselectedTextColor = MistralColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: selectedColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(segments.length, (index) {
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged?.call(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? selectedColor : unselectedColor,
                borderRadius: BorderRadius.horizontal(
                  left: index == 0 ? const Radius.circular(7) : Radius.zero,
                  right: index == segments.length - 1
                      ? const Radius.circular(7)
                      : Radius.zero,
                ),
              ),
              child: Text(
                segments[index],
                style: TextStyle(
                  color: isSelected ? selectedTextColor : unselectedTextColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 字母滑动条（翻译自 SlideBar.dart）
/// 通讯录右侧 A-Z 索引条
class AlphabetSlideBar extends StatelessWidget {
  final ValueChanged<String>? onLetterChanged;
  final Color textColor;
  final Color activeColor;

  static const List<String> _letters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  const AlphabetSlideBar({
    super.key,
    this.onLetterChanged,
    this.textColor = const Color(0xFF212121),
    this.activeColor = MistralColors.info,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPos = box.globalToLocal(details.globalPosition);
        final index = (localPos.dy / box.size.height * _letters.length)
            .clamp(0, _letters.length - 1)
            .toInt();
        onLetterChanged?.call(_letters[index]);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _letters.map((letter) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 11,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
