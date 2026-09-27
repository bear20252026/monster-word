// 由 Claude 团队生成 | Monster Word App

// 二级页面导航栏单一真相（审计 I1：此前 27 个页面各自复制 48 高
// Container + 返回箭头 + heading5 标题的实现，共 ~420 行、5 种签名形态）。
// 标题统一 Expanded + ellipsis：短标题视觉与旧实现等价，长标题不再溢出。
// 返回行为由调用方显式传入（onBack），不做静默默认——pop 与 safePop 的
// 页面语义差异保持原样。
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

class MwNavBar extends StatelessWidget {
  const MwNavBar({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
    this.height = 48,
    this.showBack = true,
    this.backTooltip,
  });

  /// 页面标题（heading5，单行省略）。
  final String title;

  /// 返回回调（Navigator.pop / NavUtils.safePop 由调用方按页面语义选择）。
  final VoidCallback? onBack;

  /// 标题右侧的动作区（计数徽章 / 文本按钮 / 图标按钮等）。
  final Widget? trailing;

  /// 导航栏高度（默认 48，部分学习页 56）。
  final double height;

  /// 是否显示返回箭头。
  final bool showBack;

  /// 返回按钮的无障碍文案。
  final String? backTooltip;

  @override
  Widget build(BuildContext context) {
    final text1 = context.skin.colors.text1;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              color: text1,
              tooltip: backTooltip,
              onPressed: onBack,
            ),
          if (showBack) const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: MwTypography.heading5.copyWith(color: text1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
