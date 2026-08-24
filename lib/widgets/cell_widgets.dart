// 由 Claude 团队生成 | Monster Word App

// 由 Claude 团队生成 | 移植自 v3.2 widget/component/ 下的单元格类组件
// 单元格与列表项组件集合
import 'package:flutter/material.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import 'input_controls.dart';
import 'input_widgets.dart';

// ─────────────────────────────────────────────────────────────
// SwitchCell — 开关单元格（移植自 component/SwitchCellView.java）
// ─────────────────────────────────────────────────────────────
class SwitchCell extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? leading;
  final bool enabled;

  const SwitchCell({
    super.key,
    required this.title,
    this.value = false,
    this.onChanged,
    this.leading,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: enabled ? skin.colors.text1 : skin.colors.text3,
              ),
            ),
          ),
          FakeSwitch(
            value: value,
            onChanged: onChanged,
            enabled: enabled,
            activeColor: skin.colors.accent,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SelectedCell — 选中单元格（移植自 component/SelectedCellView.java）
// ─────────────────────────────────────────────────────────────
class SelectedCell extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;

  const SelectedCell({
    super.key,
    required this.title,
    this.selected = false,
    this.onTap,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? skin.colors.accent.withAlpha(20) : null,
          border: Border(
            bottom: BorderSide(color: skin.colors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: selected ? skin.colors.accent : skin.colors.text1,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (trailing != null) trailing!,
            if (selected)
              Icon(Icons.check, size: 20, color: skin.colors.accent),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SelectCell2 — 选择单元格样式2（移植自 component/SelectCellStyle2View.java）
// ─────────────────────────────────────────────────────────────
class SelectCell2 extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;

  const SelectCell2({
    super.key,
    required this.title,
    this.subtitle,
    this.selected = false,
    this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: selected ? skin.colors.accent : skin.colors.text1,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 13, color: skin.colors.text3),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 20, color: skin.colors.accent)
            else
              Icon(Icons.radio_button_unchecked, size: 20, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SubtitleCell — 副标题单元格（移植自 component/SubtitleCellView.java）
// ─────────────────────────────────────────────────────────────
class SubtitleCell extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;

  const SubtitleCell({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: skin.colors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16, color: skin.colors.text1)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13, color: skin.colors.text3)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// IconCell — 图标左右单元格（移植自 component/IconLeftRightCellView.java）
// ─────────────────────────────────────────────────────────────
class IconCell extends StatelessWidget {
  final String title;
  final IconData? leftIcon;
  final IconData? rightIcon;
  final VoidCallback? onTap;
  final Color? leftIconColor;

  const IconCell({
    super.key,
    required this.title,
    this.leftIcon,
    this.rightIcon,
    this.onTap,
    this.leftIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: skin.colors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            if (leftIcon != null) ...[
              Icon(leftIcon, size: 22, color: leftIconColor ?? skin.colors.text2),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: 16, color: skin.colors.text1)),
            ),
            if (rightIcon != null)
              Icon(rightIcon, size: 18, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PopFilterCell — 弹出筛选单元格（移植自 component/PopFilterCellView.java）
// ─────────────────────────────────────────────────────────────
class PopFilterCell extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback? onTap;

  const PopFilterCell({
    super.key,
    required this.title,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? skin.colors.accent : skin.colors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? skin.colors.accent : skin.colors.divider,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: selected ? Colors.white : skin.colors.text2,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// UrlCell — URL 单元格（移植自 widget/UrlCellView.java）
// ─────────────────────────────────────────────────────────────
class UrlCell extends StatelessWidget {
  final String title;
  final String url;
  final VoidCallback? onTap;

  const UrlCell({
    super.key,
    required this.title,
    required this.url,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: skin.colors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16, color: skin.colors.text1)),
                  const SizedBox(height: 2),
                  Text(url,
                      style: TextStyle(
                          fontSize: 13, color: skin.colors.accent)),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 18, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// UserBindItem — 用户绑定项（移植自 widget/UserBindItemView.java）
// ─────────────────────────────────────────────────────────────
class UserBindItem extends StatelessWidget {
  final String platform;
  final String? account;
  final bool bound;
  final VoidCallback? onTap;

  const UserBindItem({
    super.key,
    required this.platform,
    this.account,
    this.bound = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: skin.colors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.link, size: 22, color: skin.colors.text2),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(platform,
                      style: TextStyle(
                          fontSize: 16, color: skin.colors.text1)),
                  if (account != null)
                    Text(account!,
                        style: TextStyle(
                            fontSize: 13, color: skin.colors.text3)),
                ],
              ),
            ),
            Text(
              bound ? '已绑定' : '未绑定',
              style: TextStyle(
                fontSize: 14,
                color: bound ? skin.colors.accent : skin.colors.text3,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }
}
