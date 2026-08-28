import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';
import 'book_state.dart';
import 'book_words_page.dart';

/// 词书模块首页（仪表盘）。
///
/// 展示当前词书信息、学习进度与快捷入口。
/// 通过 [BookState] 获取数据。
class BookDashboardPage extends StatelessWidget {
  const BookDashboardPage({super.key});

  static const String routeName = '/books';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, skin),
              const SizedBox(height: AppSpacing.lg),
              _buildCurrentBookCard(context, skin),
              const SizedBox(height: AppSpacing.lg),
              _buildQuickActions(context, skin),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeVars skin) {
    return Text(
      '词书',
      style: MistralTypography.heading2
          .copyWith(color: skin.text1, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildCurrentBookCard(BuildContext context, ThemeVars skin) {
    return Consumer<BookState>(
      builder: (context, state, _) {
        final book = state.currentBook;
        final stats = state.statistics;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: skin.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: skin.divider, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前词书',
                style: MistralTypography.bodySm.copyWith(color: skin.text3),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                book?.name ?? '未选择',
                style: MistralTypography.heading4.copyWith(
                    color: skin.text1, fontWeight: FontWeight.w600),
              ),
              if (book != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${book.wordCount} 词',
                  style: MistralTypography.bodyMd.copyWith(color: skin.text3),
                ),
              ],
              if (stats != null) ...[
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: LinearProgressIndicator(
                    value: stats.progress,
                    backgroundColor: skin.divider,
                    valueColor: AlwaysStoppedAnimation(skin.accent),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '已学 ${stats.learnedWords} / ${stats.totalWords} (${stats.progressText})',
                  style: MistralTypography.bodySm.copyWith(color: skin.text3),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context, ThemeVars skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '快捷入口',
          style: MistralTypography.bodyMd
              .copyWith(color: skin.text1, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.menu_book,
                label: '选择词书',
                onTap: () => Navigator.pushNamed(context, '/lib-select'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Consumer<BookState>(
                builder: (context, state, _) {
                  return _ActionCard(
                    icon: Icons.list_alt,
                    label: '单词列表',
                    onTap: state.currentBook == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChangeNotifierProvider.value(
                                  value: state,
                                  child: BookWordsPage(book: state.currentBook!),
                                ),
                              ),
                            ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: skin.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: skin.divider, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: skin.accent, size: 28),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: MistralTypography.bodySm.copyWith(color: skin.text1),
            ),
          ],
        ),
      ),
    );
  }
}
