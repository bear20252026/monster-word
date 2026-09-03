import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/core/application/wordbook_maintenance_service.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/application/learning_favorites_store.dart';
import 'package:word_app/features/learning/application/learning_session_starter.dart';
import 'package:word_app/features/learning/application/new_words_store.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/widgets/common/mw_skeleton.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/features/book/presentation/book_state.dart';

/// 词书单词列表页。
///
/// 展示当前选中词书的单词列表，支持发音、收藏、生词标记。
/// 通过 [BookState] 获取数据，通过 learning 模块状态管理收藏/生词。
class BookWordsPage extends StatefulWidget {
  const BookWordsPage({super.key, required this.book});

  final Book book;

  static const String routeName = '/book-words';

  /// 启动当前词书的学习会话并进入沉浸刷词页。
  @override
  State<BookWordsPage> createState() => _BookWordsPageState();
}

class _BookWordsPageState extends State<BookWordsPage> {
  @override
  void initState() {
    super.initState();
    // 核心修复（2026-08-31）：此前本页从不加载词书数据——state.words 永远是空的
    // （v2.4.3 前"暂无单词数据"的真正根因：只有走过选书流程才会填充）。
    // 进入详情页即加载该词书全部单词。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BookState>().selectAndLoad(widget.book);
    });
  }

  @override
  void didUpdateWidget(covariant BookWordsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<BookState>().selectAndLoad(widget.book);
      });
    }
  }

  Future<void> _startLearning(BuildContext context) async {
    await context.read<LearningSessionStarter>().startBookSession(widget.book, limit: 50);
    if (!context.mounted) return;
    Navigator.pushNamed(context, RouteNames.immersiveSwipe);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final book = widget.book;

    return Scaffold(
      backgroundColor: skin.pageBg,
      appBar: AppBar(
        backgroundColor: skin.cardBg,
        elevation: 0,
        iconTheme: IconThemeData(color: skin.text1),
        title: Text(book.name, style: MistralTypography.heading5.copyWith(color: skin.text1)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startLearning(context),
        icon: const Icon(Icons.play_arrow),
        label: const Text('开始学习'),
      ),
      body: Consumer<BookState>(
        builder: (context, state, _) {
          if (state.wordsLoading) {
            return const MwSkeletonPage(rows: 6);
          }
          final words = state.words;
          if (words.isEmpty) {
            // 词库 100% 内置离线，此处为空 = 本地库残留旧数据或查询异常。
            // 展示真实错误与诊断信息（books/words/word_books 计数），提供
            // 一键全量重建（不联网）。
            return _WordListEmptyDiagnostics(
              error: state.error,
              bookId: book.id,
              bookName: book.name,
              onRebuild: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                final bookState = context.read<BookState>();
                try {
                  final result = await context.read<WordBookMaintenanceService>().forceRebuild();
                  await bookState.reloadWords();
                  messenger?.showSnackBar(
                    SnackBar(
                      content: Text(result.success ? '重建成功: ${result.books} 本词书 / ${result.words} 词条' : result.message),
                    ),
                  );
                } catch (e) {
                  messenger?.showSnackBar(SnackBar(content: Text('重建失败: $e')));
                }
              },
            );
          }
          return ListView.builder(
            padding: EdgeInsets.all(context.design.spacing.md),
            // +1：首项为词数统计头（验收标准：总数与词书标注一致）
            itemCount: words.length + 1,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: EdgeInsets.only(bottom: context.design.spacing.sm),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '共 ${words.length} 词（按字母排序）',
                      style: MistralTypography.micro.copyWith(color: skin.text3),
                    ),
                  ),
                );
              }
              final word = words[index - 1];
              return _WordCard(word: word, book: book);
            },
          );
        },
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.word, required this.book});

  final Word word;
  final Book book;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final favorites = context.watch<LearningFavoritesStore>();
    final newWords = context.watch<NewWordsStore>();
    final isFav = favorites.isFavorite(word.word);
    final isNew = newWords.isNewWord(word.id);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, RouteNames.wordDetail, arguments: word),
      child: Container(
        margin: EdgeInsets.only(bottom: context.design.spacing.sm),
        padding: EdgeInsets.all(context.design.spacing.md),
        decoration: BoxDecoration(
          color: skin.cardBg,
          borderRadius: BorderRadius.circular(context.design.radius.xl),
          border: Border.all(color: skin.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        word.word,
                        style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
                      ),
                      if (word.usPron.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('/${word.usPron}/', style: MistralTypography.bodySm.copyWith(color: skin.text3)),
                      ],
                    ],
                  ),
                  if (word.firstInterpretLine.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      word.firstInterpretLine,
                      style: MistralTypography.bodySm.copyWith(color: skin.text3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isFav ? Icons.star : Icons.star_border,
                color: isFav ? MistralColors.primary : skin.text3,
                size: 22,
              ),
              onPressed: () => favorites.toggle(word.word),
            ),
            IconButton(
              icon: Icon(
                isNew ? Icons.bookmark_added : Icons.bookmark_add_outlined,
                color: isNew ? MistralColors.primary : skin.text3,
                size: 22,
              ),
              onPressed: () => newWords.toggleNewWord(word, source: 'book-${book.id}'),
            ),
            IconButton(
              icon: Icon(Icons.volume_up, color: skin.accent, size: 22),
              onPressed: () => context.read<AudioPlaybackState>().playWord(word.word),
            ),
          ],
        ),
      ),
    );
  }
}

/// 词书单词列表空态 + 诊断信息（词库异常时可远程定位根因）
class _WordListEmptyDiagnostics extends StatelessWidget {
  final String? error;
  final int bookId;
  final String bookName;
  final Future<void> Function() onRebuild;

  const _WordListEmptyDiagnostics({
    required this.error,
    required this.bookId,
    required this.bookName,
    required this.onRebuild,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return FutureBuilder<DbDiagnostics>(
      future: context.read<WordBookMaintenanceService>().diagnostics(),
      builder: (context, snap) {
        final diag = snap.data;
        final diagText = diag == null
            ? '诊断信息加载中…'
            : 'bookId=$bookId\n'
                  '${diag.books} 本词书 / ${diag.words} 词条 / ${diag.links} 条关联\n'
                  '库文件: ${(diag.dbFileBytes / 1048576).toStringAsFixed(1)} MB\n'
                  '更新时间: ${diag.dbModifiedAt}'
                  '${diag.error == null ? '' : '\n异常: ${diag.error}'}';
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.design.spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storage_outlined, size: 48, color: skin.colors.text3),
                SizedBox(height: context.design.spacing.md),
                Text('本地词库暂无该书数据', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
                SizedBox(height: context.design.spacing.sm),
                Text('词库 100% 内置于安装包，此问题不需要联网。', style: MistralTypography.bodySm.copyWith(color: skin.colors.text2)),
                if (error != null) ...[
                  SizedBox(height: context.design.spacing.sm),
                  Text(
                    '错误详情: $error',
                    style: MistralTypography.micro.copyWith(color: skin.colors.danger),
                    textAlign: TextAlign.center,
                  ),
                ],
                SizedBox(height: context.design.spacing.md),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: skin.colors.cardBgAlt,
                    borderRadius: BorderRadius.circular(skin.design.radius.md),
                    border: Border.all(color: skin.colors.divider),
                  ),
                  child: Text(diagText, style: MistralTypography.micro.copyWith(color: skin.colors.text2, height: 1.6)),
                ),
                SizedBox(height: context.design.spacing.md),
                FilledButton.icon(
                  onPressed: onRebuild,
                  icon: const Icon(Icons.build_outlined, size: 18),
                  label: const Text('一键重建词库（不联网）'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
