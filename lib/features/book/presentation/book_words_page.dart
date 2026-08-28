import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../core/audio/audio_playback_state.dart';
import '../../../features/learning/presentation/learning_favorites_state.dart';
import '../../../features/learning/presentation/new_words_state.dart';
import '../../../models/book.dart';
import '../../../models/word.dart';
import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';
import 'book_state.dart';

/// 词书单词列表页。
///
/// 展示当前选中词书的单词列表，支持发音、收藏、生词标记。
/// 通过 [BookState] 获取数据，通过 learning 模块状态管理收藏/生词。
class BookWordsPage extends StatelessWidget {
  const BookWordsPage({super.key, required this.book});

  final Book book;

  static const String routeName = '/book-words';

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
      body: Consumer<BookState>(
        builder: (context, state, _) {
          if (state.wordsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final words = state.words;
          if (words.isEmpty) {
            return Center(
              child: Text(
                '暂无单词数据',
                style: MistralTypography.bodyMd.copyWith(color: skin.text3),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
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
    final favorites = context.watch<LearningFavoritesState>();
    final newWords = context.watch<NewWordsState>();
    final isFav = favorites.isFavorite(word.word);
    final isNew = newWords.isNewWord(word.id);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
    );
  }
}
