// Monster Word — 共享列表行（淡色图标块 + 标题 + 值 + 箭头）。
// 个人中心/设置/我的内容/装备架等菜单行的统一实现，替换各页私有 _MenuItem。
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';

class MwListRow extends StatelessWidget {
  const MwListRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.value,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? value;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return ScaleDownOnPress(
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(context.design.radius.sm),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MwTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w500),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: MwTypography.micro.copyWith(color: skin.text3)),
                    ],
                  ],
                ),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(value!, style: MwTypography.bodySm.copyWith(color: skin.text2)),
                ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(Icons.chevron_right, size: 18, color: skin.text3),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分组容器：白卡 + 行间发丝线。
class MwListGroup extends StatelessWidget {
  const MwListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: skin.cardBg, borderRadius: BorderRadius.circular(context.design.radius.lg)),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 0.5, thickness: 0.5, indent: 66, color: skin.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}
