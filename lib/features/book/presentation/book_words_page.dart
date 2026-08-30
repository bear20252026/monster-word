import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/core/learning/learning_favorites_store.dart';
import 'package:word_app/core/learning/learning_session_starter.dart';
import 'package:word_app/core/learning/new_words_store.dart';
import 'package:word_app/core/router/route_names.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/widgets/common/mw_skeleton.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/features/book/presentation/book_state.dart';

/// 词书单词列表页。
///
/// 展示当前选中词书的单词列表，支持发音、收藏、生词标记。
/// 通过 [BookState] 获取数据，通过 learning 模块状态管理收藏/生词。
class BookWordsPage extends StatelessWidget {
  const BookWordsPage({super.key, required this.book});

  final Book book;

  static const String routeName = '/book-words';

  /// 启动当前词书的学习会话并进入沉浸刷词页。
  Future<void> _startLearning(BuildContext context) async {
    await context.read<LearningSessionStarter>().startBookSession(book, limit: 50);
    if (!context.mounted) return;
    Navigator.pushNamed(context, RouteNames.immersiveSwipe);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return Scaffold(
      backgroundColor: skin.pageBg,
      appBar: AppBar(
        backgroundColor: skin.cardBg,
        elevation: 0,
        iconTheme: IconThemeData(color: skin.text1),
        title: Text(
          book.name,
          style: MistralTypography.heading5
              .copyWith(color: skin.text1, fontWeight: FontWeight.w600),
        ),
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
            return Center(
              child: Text(
                '词库数据需要更新',
                style: MistralTypography.bodyMd.copyWith(color: skin.text3),
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.all(context.design.spacing.md),
            itemCount: words.length,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              final word = words[index];
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
      onTap: () => Navigator.pushNamed(
        context,
        RouteNames.wordDetail,
        arguments: word,
      ),
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
                Text(
                  word.word,
                  style: MistralTypography.bodyMd.copyWith(
                      color: skin.text1, fontWeight: FontWeight.w600),
                ),
                if (word.usPron.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    word.usPron,
                    style: MistralTypography.bodySm.copyWith(color: skin.text3),
                  ),
                ],
                if (word.firstInterpretLine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    word.firstInterpretLine,
                    style: MistralTypography.bodySm.copyWith(color: skin.text3),
                    maxLines: 2,
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
            onPressed: () =>
                newWords.toggleNewWord(word, source: 'book-${book.id}'),
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
