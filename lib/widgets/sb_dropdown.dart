// 星巴克下拉菜单组件（component_spec.md §7）
// 使用 ThemeVars 语义 token，支持深色模式
import 'package:flutter/material.dart';

import '../theme/skin_system.dart';

/// 显示星巴克风格下拉菜单
///
/// - [anchor] 触发行的 RenderBox（用于定位）
/// - [items] Map<T, String> 键值对，T 为业务值，String 为显示文本
/// - [selected] 当前选中值（高亮态：绿字 w600 + tint 底）
/// - [label] 可选的前缀标签
Future<T?> showSbDropdown<T>({
  required BuildContext context,
  required RenderBox anchor,
  required Map<T, String> items,
  T? selected,
  String? label,
}) {
  final size = MediaQuery.of(context).size;
  final skin = context.skin;
  final colors = skin.colors;

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
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.text2),
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
              ? BoxDecoration(color: colors.accent.withValues(alpha: 0.33), borderRadius: BorderRadius.circular(8))
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            e.value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? colors.accent : colors.text1,
            ),
          ),
        ),
      ),
    );
  }

  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(
      anchor.localToGlobal(Offset(0, anchor.size.height)) & Size(anchor.size.width, 0),
      Offset.zero & size,
    ),
    color: colors.cardBg,
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    constraints: BoxConstraints(minWidth: anchor.size.width),
    items: menuItems,
  );
}
