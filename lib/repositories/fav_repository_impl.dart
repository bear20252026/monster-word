// 收藏仓库实现
// 基于 SharedPreferences（单词收藏）和 FavSentenceDao（句子收藏）
import 'package:shared_preferences/shared_preferences.dart';

import '../data/fav_sentence_dao.dart';
import '../models/sentence_models.dart';
import 'fav_repository.dart';

/// 收藏仓库实现
class FavRepositoryImpl implements FavRepository {
  static const _kFavoritesKey = 'favorite_words_v1';
  Set<String> _favoriteWords = {};

  FavRepositoryImpl() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kFavoritesKey);
      if (raw != null) _favoriteWords.addAll(raw);
    } catch (_) {}
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFavoritesKey, _favoriteWords.toList());
  }

  // ── 单词收藏 ──

  @override
  Future<Set<String>> getFavoriteWords() async {
    if (_favoriteWords.isEmpty) await _loadFavorites();
    return Set.from(_favoriteWords);
  }

  @override
  Future<void> addFavorite(String word) async {
    _favoriteWords.add(word);
    await _saveFavorites();
  }

  @override
  Future<void> removeFavorite(String word) async {
    _favoriteWords.remove(word);
    await _saveFavorites();
  }

  @override
  Future<void> toggleFavorite(String word) async {
    if (_favoriteWords.contains(word)) {
      _favoriteWords.remove(word);
    } else {
      _favoriteWords.add(word);
    }
    await _saveFavorites();
  }

  @override
  bool isFavorite(String word) => _favoriteWords.contains(word);

  @override
  int get favoriteCount => _favoriteWords.length;

  // ── 句子收藏 ──

  @override
  Future<List<Map<String, dynamic>>> getFavoriteSentences() async {
    final sentences = await FavSentenceDao.instance.loadAll();
    return sentences.map((s) => {
      'wordId': s.wordId,
      'sentenceId': s.sentenceId,
      'sentenceData': s.sentenceData,
      'wordUsage': s.wordUsage,
      'updateTime': s.updateTime,
      'type': s.type,
    }).toList();
  }

  @override
  Future<bool> addFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) async {
    final sentenceData = SentenceData(
      sid: sentenceId,
      e: english,
      c: chinese,
      b: source,
    );
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
    final sentenceData = SentenceData(
      sid: sentenceId,
      e: english,
      c: chinese,
      b: source,
    );
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
