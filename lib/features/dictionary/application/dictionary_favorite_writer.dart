/// 收藏操作端口（写）。
///
/// 封装单词收藏/取消收藏逻辑，写操作经此端口委托给 data 层。
abstract class DictionaryFavoriteWriter {
  /// 切换单词收藏状态，返回切换后是否已收藏。
  Future<bool> toggleFavorite(String word);

  /// 判断单词是否已收藏。
  bool isFavorite(String word);

  /// 获取所有已收藏单词。
  Future<Set<String>> getFavoriteWords();
}
