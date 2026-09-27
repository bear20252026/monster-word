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

  /// 审计 I35：[word] 为例句所属单词文本（favorite_sentences.word 列的
  /// 建表语义），此前实现层硬编码空串导致该列恒空。
  Future<bool> addFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
    String word = '',
  });
  Future<bool> removeFavoriteSentence(int wordId, String sentenceId);

  /// 审计 I19：批量取消收藏（单事务）。返回实际移除的条数。
  Future<int> removeFavoriteSentences(List<({int wordId, String sentenceId})> items);
  Future<bool> toggleFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
    String word = '',
  });
  Future<bool> isFavoriteSentence(int wordId, String sentenceId);
  int get favoriteSentenceCount;
}
