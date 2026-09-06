// 由 Claude 团队生成 | Monster Word App

// 足迹页：显示学习记录入口（全部已学单词、生词本等）
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/features/learning/application/learning_collections_reader.dart';
import 'package:word_app/features/learning/application/learning_session_reader.dart';
import 'package:word_app/features/learning/application/learning_statistics_reader.dart';
import 'package:word_app/features/learning/application/new_words_store.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/func_colors.dart';

class FootMarkPage extends StatelessWidget {
  const FootMarkPage({super.key});

  static const routeName = '/foot_mark';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final session = context.read<LearningSessionReader>();
    final statistics = context.watch<LearningStatisticsReader>();
    final collections = context.watch<LearningCollectionsReader>();
    final newWords = context.watch<NewWordsStore>();

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin, context),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildStatCard(context, skin, statistics),
                    const SizedBox(height: 16),
                    _buildEntryCard(
                      context: context,
                      skin: skin,
                      icon: Icons.menu_book,
                      color: skin.colors.success,
                      title: '全部已学单词',
                      count: session.learnedNum,
                      onTap: () => Navigator.pushNamed(context, RouteNames.myWords),
                    ),
                    const SizedBox(height: 12),
                    _buildEntryCard(
                      context: context,
                      skin: skin,
                      icon: Icons.fiber_new,
                      color: FuncColors.info,
                      title: '生词本',
                      count: newWords.count,
                      onTap: () => Navigator.pushNamed(context, RouteNames.newWords),
                    ),
                    const SizedBox(height: 12),
                    _buildEntryCard(
                      context: context,
                      skin: skin,
                      icon: Icons.check_circle_outline,
                      color: skin.colors.accent,
                      title: '已掌握单词',
                      count: collections.masteredCount,
                      onTap: () => Navigator.pushNamed(context, RouteNames.masteredWords),
                    ),
                    const SizedBox(height: 12),
                    _buildEntryCard(
                      context: context,
                      skin: skin,
                      icon: Icons.hourglass_empty,
                      color: FuncColors.warning,
                      title: '未学习单词',
                      count: session.total - session.learnedNum,
                      onTap: () => Navigator.pushNamed(context, RouteNames.notLearnedWords),
                    ),
                    const SizedBox(height: 12),
                    _buildEntryCard(
                      context: context,
                      skin: skin,
                      icon: Icons.replay,
                      color: skin.colors.danger,
                      title: '复习中单词',
                      count: statistics.dueCount,
                      onTap: () => Navigator.pushNamed(context, RouteNames.reviewingWords),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin, BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('足迹', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, SkinSystem skin, LearningStatisticsReader statistics) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [skin.colors.cardBg, skin.colors.cardBgAlt]),
        borderRadius: BorderRadius.circular(context.design.radius.xl),
        border: Border.all(color: skin.colors.divider),
      ),
      child: Column(
        children: [
          Text('${statistics.totalLearnedDays}', style: MwTypography.heading1.copyWith(color: skin.colors.accent)),
          const SizedBox(height: 4),
          Text('累计学习天数', style: MwTypography.body.copyWith(color: skin.colors.text3)),
        ],
      ),
    );
  }

  Widget _buildEntryCard({
    required BuildContext context,
    required SkinSystem skin,
    required IconData icon,
    required Color color,
    required String title,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: skin.colors.cardBg,
          borderRadius: BorderRadius.circular(context.design.radius.lg),
          border: Border.all(color: skin.colors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(context.design.radius.md),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: MwTypography.bodyMd.copyWith(color: skin.colors.text1, fontWeight: FontWeight.w600),
              ),
            ),
            Text('$count', style: MwTypography.heading5.copyWith(color: color)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }
}
