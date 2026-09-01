// 设置功能弹窗通用骨架：拖拽条 + 标题 + 关闭按钮 + 内容。
// 此前内联在 settings_page._showBottomSheet，拆出供设置页与学习提醒弹窗复用。
import 'package:flutter/material.dart';

import 'package:word_app/core/router/nav_utils.dart';
import 'package:word_app/theme/skin_system.dart';

Future<T?> showSettingsBottomSheet<T>(BuildContext context, {required String title, required Widget child}) {
  final skin = context.skin.colors;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Container(
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖拽条 + 关闭按钮
          Row(
            children: [
              const SizedBox(width: 36),
              Expanded(
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: skin.divider, borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => NavUtils.safePop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  child: Icon(Icons.close, size: 20, color: skin.text3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 标题
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: skin.text1),
          ),
          const SizedBox(height: 16),
          // 内容
          child,
        ],
      ),
    ),
  );
}

/// 弹窗开关行（设置页各弹窗共用）。
class SettingsSheetSwitchRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const SettingsSheetSwitchRow({super.key, required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: TextStyle(fontSize: 15, color: skin.text1)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: skin.accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: skin.text3,
          ),
        ],
      ),
    );
  }
}

/// 弹窗选项行（橙色对勾，设置页各弹窗共用）。
class SettingsSheetOptionRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const SettingsSheetOptionRow({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: selected ? skin.accent : skin.text1,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, size: 22, color: skin.accent),
          ],
        ),
      ),
    );
  }
}
