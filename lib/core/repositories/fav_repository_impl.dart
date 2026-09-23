// 收藏仓库实现
// MEM/U6：单词收藏经 FavoriteWordsDao（SQLite 事实来源 + 同步读索引，
// 测试/开库失败回退 SP）；句子收藏经 FavSentenceDao（MEM/U3 同策略）。
import 'dart:async';

import 'package:word_app/core/infrastructure/favorite_words_dao.dart';

import 'package:word_app/models/sentence_models.dart';
import 'package:word_app/core/repositories/fav_repository.dart';

import 'package:word_app/core/infrastructure/fav_sentence_dao.dart';

/// 收藏仓库实现
class FavRepositoryImpl implements FavRepository {
  FavRepositoryImpl() {
    // 预热同步读索引（构造即加载，与迁移前构造加载 SP 语义一致）
    unawaited(FavoriteWordsDao.instance.ensureLoaded());
  }

  // ── 单词收藏（MEM/U6：SQLite + 索引） ──

  @override
  Future<Set<String>> getFavoriteWords() async => FavoriteWordsDao.instance.getWords();

  @override
  Future<void> addFavorite(String word) => FavoriteWordsDao.instance.add(word);

  @override
  Future<void> removeFavorite(String word) => FavoriteWordsDao.instance.remove(word);

  @override
  Future<void> toggleFavorite(String word) => FavoriteWordsDao.instance.toggle(word);

  @override
  bool isFavorite(String word) => FavoriteWordsDao.instance.isFavorite(word);

  @override
  int get favoriteCount => FavoriteWordsDao.instance.favoriteCount;

  // ── 句子收藏 ──

  @override
  Future<List<Map<String, dynamic>>> getFavoriteSentences() async {
    final sentences = await FavSentenceDao.instance.loadAll();
    return sentences
        .map(
          (s) => {
            'wordId': s.wordId,
            'sentenceId': s.sentenceId,
            'sentenceData': s.sentenceData,
            'wordUsage': s.wordUsage,
            'updateTime': s.updateTime,
            'type': s.type,
          },
        )
        .toList();
  }

  @override
  Future<bool> addFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) async {
    final sentenceData = SentenceData(sid: sentenceId, e: english, c: chinese, b: source);
    return await FavSentenceDao.instance.addFavSentence(
      word: '',
      wordId: wordId,
      sentenceId: sentenceId,
      sentenceData: sentenceData,
    );
  }

  @override
  Future<bool> removeFavoriteSentence(int wordId, String sentenceId) {
    return FavSentenceDao.instance.removeFavSentence(wordId, sentenceId);
  }

  @override
  Future<bool> toggleFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) async {
    final sentenceData = SentenceData(sid: sentenceId, e: english, c: chinese, b: source);
    return await FavSentenceDao.instance.toggleFavSentence(
      word: '',
      wordId: wordId,
      sentenceId: sentenceId,
      sentenceData: sentenceData,
    );
  }

  @override
  Future<bool> isFavoriteSentence(int wordId, String sentenceId) async {
    return FavSentenceDao.instance.isFavSentence(wordId, sentenceId);
  }

  @override
  int get favoriteSentenceCount => FavSentenceDao.instance.favCount;
}
