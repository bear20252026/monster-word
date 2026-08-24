// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 单元格/列表控件：翻译自 widget/ 中的单元格类
// 文件：SwitchCellView, UrlCellView, UserBindItemView, SubListView, MyExpandleListView

import 'package:flutter/material.dart';
import 'input_controls.dart';
import '../tokens/design_tokens.dart';

/// 开关单元格（翻译自 SwitchCellView.dart）
/// 左侧标题 + 右侧开关
class SwitchCellView extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? leading;
  final bool enabled;
  final Color accentColor;

  const SwitchCellView({
    super.key,
    required this.title,
    required this.value,
    this.onChanged,
    this.leading,
    this.enabled = true,
    this.accentColor = kSwitchActiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () => onChanged?.call(!value) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: enabled ? MistralColors.charcoal : MistralColors.steel,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: accentColor,
              activeTrackColor: accentColor.withAlpha(128),
              inactiveThumbColor: kSwitchThumbColor,
              inactiveTrackColor: kSwitchInactiveColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// 垂直等级视图（翻译自 VerticalLevelView.dart）
/// 垂直的进度条，从底部向上填充
class VerticalLevelBar extends StatelessWidget {
  final int totalLevel;
  final int currentLevel;
  final Color bgColor;
  final Color progressColor;
  final Color fullProgressColor;
  final double width;
  final double height;
  final double radius;

  const VerticalLevelBar({
    super.key,
    required this.totalLevel,
    required this.currentLevel,
    this.bgColor = const Color(0x08000000),
    this.progressColor = MistralColors.warning,
    this.fullProgressColor = MistralColors.success,
    this.width = 20,
    this.height = 100,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = currentLevel >= totalLevel;
    final progressFraction =
        totalLevel > 0 ? (currentLevel / totalLevel).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isFull ? null : bgColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            // 背景
            if (!isFull)
              Container(color: bgColor),
            // 进度（从底部向上）
            if (isFull)
              Container(color: fullProgressColor)
            else if (currentLevel > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: height * progressFraction,
                child: Container(
                  decoration: BoxDecoration(
                    color: progressColor,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(radius),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// URL 单元格列表（翻译自 UrlCellView.dart）
class UrlCellList extends StatelessWidget {
  final List<UrlCellItem> items;
  final ValueChanged<String>? onItemTap;

  const UrlCellList({
    super.key,
    required this.items,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) {
        return ListTile(
          title: Text(item.title),
          subtitle: item.subtitle.isNotEmpty ? Text(item.subtitle) : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onItemTap?.call(item.url),
        );
      }).toList(),
    );
  }
}

class UrlCellItem {
  final String title;
  final String subtitle;
  final String url;

  const UrlCellItem({
    required this.title,
    this.subtitle = '',
    required this.url,
  });
}

/// 用户绑定项（翻译自 UserBindItemView.dart）
class UserBindItem extends StatelessWidget {
  final String bindName;
  final bool isBound;
  final String statusText;
  final VoidCallback? onTap;

  const UserBindItem({
    super.key,
    required this.bindName,
    required this.isBound,
    this.statusText = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(bindName),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            statusText.isNotEmpty
                ? statusText
                : (isBound ? '已绑定' : '立即绑定'),
            style: TextStyle(
              color: isBound ? MistralColors.steel : MistralColors.link,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// 可展开列表（翻译自 MyExpandleListView.dart）
/// Flutter 中使用 ExpansionTile 替代
class ExpandableListView extends StatelessWidget {
  final List<ExpandableGroup> groups;

  const ExpandableListView({super.key, required this.groups});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: groups.map((group) {
        return ExpansionTile(
          title: Text(group.title),
          initiallyExpanded: group.isExpanded,
          children: group.items.map((item) => item).toList(),
        );
      }).toList(),
    );
  }
}

class ExpandableGroup {
  final String title;
  final List<Widget> items;
  final bool isExpanded;

  const ExpandableGroup({
    required this.title,
    required this.items,
    this.isExpanded = false,
  });
}

/// 子列表视图（翻译自 SubListView.dart）
/// 自动展开所有子项高度的列表
class ExpandedListView extends StatelessWidget {
  final List<Widget> children;
  final Axis scrollDirection;
  final EdgeInsetsGeometry? padding;

  const ExpandedListView({
    super.key,
    required this.children,
    this.scrollDirection = Axis.vertical,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: scrollDirection,
      padding: padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}
