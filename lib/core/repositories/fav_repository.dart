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

  /// MEM/U3+分页：按更新时间倒序分页读取收藏例句（句库页窗口化）。
  Future<List<Map<String, dynamic>>> getFavoriteSentencesPage({required int limit, int offset = 0});

  /// 收藏例句总数（SQL COUNT 口径，不加载载荷）。
  Future<int> getFavoriteSentenceCount();
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
