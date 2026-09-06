// Monster Word — 共享编辑式区块头（竖条 + 标题 + 延伸发丝线）。
// 出现在词典/仪表盘/我的空间/装备架等页面，保证全局区块语言完全一致。
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

class MwSectionHeader extends StatelessWidget {
  const MwSectionHeader({super.key, required this.title, this.action});

  final String title;

  /// 可选的动作（如「查看全部」），靠右。
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(color: skin.accent, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: MwTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 0.5, color: skin.divider)),
        if (action != null) ...[const SizedBox(width: 8), action!],
      ],
    );
  }
}
