// 星巴克下拉菜单组件（component_spec.md §7）
// #F9F9F9 底色、12px 圆角、绿字高亮、200ms 展开动画
import 'package:flutter/material.dart';

/// 显示星巴克风格下拉菜单
///
/// - [anchor] 触发行的 RenderBox（用于定位）
/// - [items] Map<T, String> 键值对，T 为业务值，String 为显示文本
/// - [selected] 当前选中值（高亮态：绿字 #00754A w600 + tint 底）
/// - [label] 可选的前缀标签
Future<T?> showSbDropdown<T>({
  required BuildContext context,
  required RenderBox anchor,
  required Map<T, String> items,
  T? selected,
  String? label,
}) {
  final size = MediaQuery.of(context).size;

  // 构建菜单项列表
  final menuItems = <PopupMenuItem<T>>[];

  // 可选的 label 前缀
  if (label != null) {
    menuItems.add(
      PopupMenuItem<T>(
        enabled: false,
        height: 40,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0x8A000000),
          ),
        ),
      ),
    );
  }

  // 添加选项
  for (final e in items.entries) {
    final isSelected = e.key == selected;
    menuItems.add(
      PopupMenuItem<T>(
        value: e.key,
        height: 44,
        child: Container(
          decoration: isSelected
              ? BoxDecoration(
                  color: const Color(0x5400754A), // green-light @33%
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            e.value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? const Color(0xFF00754A) // 绿字高亮
                  : const Color(0xDE000000), // 黑 87%
            ),
          ),
        ),
      ),
    );
  }

  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(
      anchor.localToGlobal(Offset(0, anchor.size.height)) &
          Size(anchor.size.width, 0),
      Offset.zero & size,
    ),
    color: const Color(0xFFF9F9F9), // Neutral Cool 无边框
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    constraints: BoxConstraints(minWidth: anchor.size.width),
    items: menuItems,
  );
}
