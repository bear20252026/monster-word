// 收藏数据访问抽象层
// 封装单词收藏和句子收藏操作

/// 收藏仓库接口
abstract class FavRepository {
  // ── 单词收藏 ──
  Future<Set<String>> getFavoriteWords();
  Future<void> addFavorite(String word);
  Future<void> removeFavorite(String word);
  Future<void> toggleFavorite(String word);
  bool isFavorite(String word);
  int get favoriteCount;

  // ── 句子收藏 ──
  Future<List<Map<String, dynamic>>> getFavoriteSentences();
  Future<bool> addFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  });
  Future<bool> removeFavoriteSentence(int wordId, String sentenceId);
  Future<bool> toggleFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  });
  Future<bool> isFavoriteSentence(int wordId, String sentenceId);
  int get favoriteSentenceCount;
}
