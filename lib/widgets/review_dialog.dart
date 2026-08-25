// 回顾弹窗：今日已学 + 今日复习统计
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

/// 显示回顾弹窗
void showReviewDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ReviewDialog(),
  );
}

class _ReviewDialog extends StatelessWidget {
  const _ReviewDialog();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final state = context.read<LearningState>();

    return Container(
      decoration: BoxDecoration(
        color: skin.pageBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示条
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: skin.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Text('回顾', style: MistralTypography.heading5.copyWith(color: skin.text1)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: skin.text3, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 统计卡片区域
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: _StatCard(
                    label: '今日已学',
                    value: '${state.todayLearnCount}',
                    unit: '词',
                    icon: Icons.school_outlined,
                    color: skin.accent,
                    skin: skin,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    label: '今日复习',
                    value: '${state.todayReviewCount}',
                    unit: '词',
                    icon: Icons.replay_outlined,
                    color: skin.success,
                    skin: skin,
                  )),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('学习进度', style: MistralTypography.caption.copyWith(color: skin.text3)),
                      Text(
                        state.total > 0
                            ? '${((state.learnedNum / state.total) * 100).toInt()}%'
                            : '0%',
                        style: MistralTypography.captionBold.copyWith(color: skin.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: state.total > 0 ? state.learnedNum / state.total : 0,
                      minHeight: 8,
                      backgroundColor: skin.divider,
                      valueColor: AlwaysStoppedAnimation(skin.accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 底部按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // 修复：先捕获页面级 Navigator 再关弹窗，避免在已失活的
                        // bottom sheet context 上调用 pushNamed（会抛 deactivated widget 异常）
                        final nav = Navigator.of(context);
                        nav.pop();
                        nav.pushNamed('/learn');
                      },
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('继续学习'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: skin.accent,
                        side: BorderSide(color: skin.accent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // 修复：同上，先捕获 Navigator 再关弹窗
                        final nav = Navigator.of(context);
                        nav.pop();
                        nav.pushNamed('/review_session');
                      },
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('开始复习'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: skin.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 统计卡片
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final dynamic skin;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.skin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: skin.cardBgAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label, style: MistralTypography.micro.copyWith(color: skin.text3)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                style: MistralTypography.heading2.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                )),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit, style: MistralTypography.caption.copyWith(color: skin.text3)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
