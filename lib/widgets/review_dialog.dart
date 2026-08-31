// 回顾弹窗：今日已学 + 今日复习统计
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/learning/application/review_schedule_reader.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/features/learning/presentation/review_page.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

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
    final session = context.watch<LearningSessionState>();
    final schedule = context.watch<ReviewScheduleReader>();

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
              decoration: BoxDecoration(color: skin.divider, borderRadius: BorderRadius.circular(2)),
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
            // A-5: dueCount==0 时展示友好空态，而非直接进入空复习。
            if (schedule.dueCount == 0)
              _buildEmptyState(context, skin)
            else
              _buildStatsAndActions(context, skin, session, schedule),
          ],
        ),
      ),
    );
  }

  /// A-5: dueCount==0 时的友好空态 — 「今天没有需要复习的单词」+ CTA。
  Widget _buildEmptyState(BuildContext context, dynamic skin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 56, color: skin.success),
          const SizedBox(height: 16),
          Text('今天没有需要复习的单词', style: MistralTypography.heading5.copyWith(color: skin.text1)),
          const SizedBox(height: 8),
          Text(
            '太棒了！今天的复习任务已完成，休息一下吧。',
            textAlign: TextAlign.center,
            style: MistralTypography.bodyMd.copyWith(color: skin.text3),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('好的'),
              style: ElevatedButton.styleFrom(
                backgroundColor: skin.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.sm)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 原有内容：统计卡片 + 进度条 + 底部按钮。
  Widget _buildStatsAndActions(
    BuildContext context,
    dynamic skin,
    LearningSessionState session,
    ReviewScheduleReader schedule,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 统计卡片区域
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: '今日已学',
                  value: '${schedule.todayLearnCount}',
                  unit: '词',
                  icon: Icons.school_outlined,
                  color: skin.accent,
                  skin: skin,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: '今日复习',
                  value: '${schedule.todayReviewCount}',
                  unit: '词',
                  icon: Icons.replay_outlined,
                  color: skin.success,
                  skin: skin,
                ),
              ),
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
                    session.total > 0 ? '${((session.learnedNum / session.total) * 100).toInt()}%' : '0%',
                    style: MistralTypography.captionBold.copyWith(color: skin.accent),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: session.total > 0 ? session.learnedNum / session.total : 0,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.sm)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.pushNamed(ReviewPage.routeName);
                  },
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('开始复习'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: skin.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.sm)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(context.design.radius.md),
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
              Text(
                value,
                style: MistralTypography.heading2.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
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
