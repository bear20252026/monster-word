// 今日路线节点地图（纯展示）：只有当前节点彩色，已完成打勾，后续灰但可点。
//
// 数据由 buildHomePathNodes 纯函数给出；点击回调由首页注入（弹层里选「开始」）。
import 'package:flutter/material.dart';

import 'package:word_app/features/learning/application/home_path.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

/// 4 节点竖排地图（热身 / 新词 / 复习 / 宝箱）。
class HomePathMap extends StatelessWidget {
  const HomePathMap({required this.nodes, required this.onNodeTap, super.key});

  final List<HomePathNode> nodes;
  final ValueChanged<int> onNodeTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    final current = homePathCurrentStep(nodes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '今日路线',
              style: MwTypography.bodySm.copyWith(fontWeight: FontWeight.w700, color: colors.text1),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              current == null ? '已走完' : '第 $current / ${nodes.length} 步',
              style: MwTypography.micro.copyWith(color: colors.text3),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < nodes.length; i++)
          _PathNodeRow(node: nodes[i], isLast: i == nodes.length - 1, onTap: () => onNodeTap(i)),
      ],
    );
  }
}

class _PathNodeRow extends StatelessWidget {
  const _PathNodeRow({required this.node, required this.isLast, required this.onTap});

  final HomePathNode node;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    final isCurrent = node.status == HomePathNodeStatus.current;
    final isDone = node.status == HomePathNodeStatus.done;
    final nodeColor = isCurrent ? colors.accent : colors.text3;
    return InkWell(
      key: ValueKey('path-node-${node.kind.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Container(
                    key: ValueKey(
                      isCurrent ? 'path-node-current-${node.kind.name}' : 'path-node-dot-${node.kind.name}',
                    ),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // 只有当前节点有彩色底与更粗的圈，其余一律灰阶
                      color: isCurrent ? nodeColor.withValues(alpha: AppAlphas.o12) : null,
                      border: Border.all(
                        color: nodeColor.withValues(alpha: isCurrent ? AppAlphas.o90 : AppAlphas.o40),
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: isDone ? Icon(Icons.check_rounded, size: 14, color: nodeColor) : null,
                  ),
                  if (!isLast) Container(width: 1.5, height: 16, color: colors.divider),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MwTypography.bodySm.copyWith(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent ? colors.text1 : colors.text3,
                    ),
                  ),
                  Text(
                    node.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MwTypography.micro.copyWith(color: colors.text3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('约 ${node.minutes} 分钟', style: MwTypography.micro.copyWith(color: colors.text3)),
          ],
        ),
      ),
    );
  }
}
