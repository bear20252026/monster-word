import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/features/book/presentation/book_state.dart';
import 'package:word_app/features/book/presentation/book_words_page.dart';

/// 词书模块首页（仪表盘）。
///
/// 展示当前词书信息、学习进度与快捷入口。
/// 通过 [BookState] 获取数据。
class BookDashboardPage extends StatelessWidget {
  const BookDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.design.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, skin),
              SizedBox(height: context.design.spacing.lg),
              _buildCurrentBookCard(context, skin),
              SizedBox(height: context.design.spacing.lg),
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
      style: MistralTypography.heading2.copyWith(color: skin.text1, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildCurrentBookCard(BuildContext context, ThemeVars skin) {
    return Consumer<BookState>(
      builder: (context, state, _) {
        final book = state.currentBook;
        final stats = state.statistics;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(context.design.spacing.lg),
          decoration: BoxDecoration(
            color: skin.cardBg,
            borderRadius: BorderRadius.circular(context.design.radius.xl),
            border: Border.all(color: skin.divider, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前词书', style: MistralTypography.bodySm.copyWith(color: skin.text3)),
              SizedBox(height: context.design.spacing.xs),
              Text(
                book?.name ?? '未选择',
                style: MistralTypography.heading4.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
              ),
              if (book != null) ...[
                SizedBox(height: context.design.spacing.sm),
                Text('${book.wordCount} 词', style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
              ],
              if (stats != null) ...[
                SizedBox(height: context.design.spacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(context.design.radius.sm),
                  child: LinearProgressIndicator(
                    value: stats.progress,
                    backgroundColor: skin.divider,
                    valueColor: AlwaysStoppedAnimation(skin.accent),
                    minHeight: 6,
                  ),
                ),
                SizedBox(height: context.design.spacing.xs),
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
          style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: context.design.spacing.sm),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.menu_book,
                label: '选择词书',
                onTap: () => Navigator.pushNamed(context, RouteNames.libSelect),
              ),
            ),
            SizedBox(width: context.design.spacing.sm),
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
  const _ActionCard({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(context.design.spacing.md),
        decoration: BoxDecoration(
          color: skin.cardBg,
          borderRadius: BorderRadius.circular(context.design.radius.lg),
          border: Border.all(color: skin.divider, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: skin.accent, size: 28),
            SizedBox(height: context.design.spacing.xs),
            Text(label, style: MistralTypography.bodySm.copyWith(color: skin.text1)),
          ],
        ),
      ),
    );
  }
}
