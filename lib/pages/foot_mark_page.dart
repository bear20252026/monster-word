// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 FootMarkActivity
// 足迹页：显示学习记录入口（全部已学单词、生词本等）
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/learning/presentation/learning_collections_state.dart';
import '../features/learning/presentation/new_words_state.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import 'my_words_page.dart';
import 'new_words_page.dart';
import 'mastered_words_page.dart';
import 'not_learned_words_page.dart';
import 'reviewing_words_page.dart';

class FootMarkPage extends StatelessWidget {
  const FootMarkPage({super.key});

  static const routeName = '/foot_mark';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final state = context.watch<LearningState>();
    final collections = context.watch<LearningCollectionsState>();
    final newWords = context.watch<NewWordsState>();

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
                    _buildStatCard(skin, state),
                    const SizedBox(height: 16),
                    _buildEntryCard(
                      skin: skin,
                      icon: Icons.menu_book,
                      title: '全部已学单词',
                      count: state.learnedNum,
                      onTap: () => Navigator.pushNamed(context, MyWordsPage.routeName),
                    ),
                    const SizedBox(height: 12),
                    _buildEntryCard(
                      skin: skin,
                      icon: Icons.fiber_new,
                      title: '生词本',
                      count: newWords.count,
                      onTap: () => Navigator.pushNamed(context, NewWordsPage.routeName),
                    ),
                    const SizedBox(height: 12),
                    _buildEntryCard(
                      skin: skin,
                      icon: Icons.check_circle_outline,
                      title: '已掌握单词',
                      count: collections.masteredCount,
                      onTap: () => Navigator.pushNamed(context, MasteredWordsPage.routeName),
                    ),
                    const SizedBox(height: 12),
                    _buildEntryCard(
                      skin: skin,
                      icon: Icons.hourglass_empty,
                      title: '未学习单词',
                      count: state.notLearnedNum,
                      onTap: () => Navigator.pushNamed(context, NotLearnedWordsPage.routeName),
                    ),
                    const SizedBox(height: 12),
                    _buildEntryCard(
                      skin: skin,
                      icon: Icons.replay,
                      title: '复习中单词',
                      count: state.reviewingNum,
                      onTap: () => Navigator.pushNamed(context, ReviewingWordsPage.routeName),
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
          Text('足迹', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }

  Widget _buildStatCard(SkinSystem skin, LearningState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [MistralColors.cream, MistralColors.creamDeeper]),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        children: [
          Text('${state.totalLearnedDays}', style: MistralTypography.heading1.copyWith(color: MistralColors.primary)),
          const SizedBox(height: 4),
          Text('累计学习天数', style: MistralTypography.body.copyWith(color: MistralColors.slate)),
        ],
      ),
    );
  }

  Widget _buildEntryCard({
    required SkinSystem skin,
    required IconData icon,
    required String title,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: skin.colors.cardBgAlt,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: skin.colors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: MistralColors.cream, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Icon(icon, color: MistralColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: MistralTypography.bodyBold.copyWith(color: skin.colors.text1)),
            ),
            Text('$count', style: MistralTypography.heading5.copyWith(color: MistralColors.primary)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }
}
