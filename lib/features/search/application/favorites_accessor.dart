// 搜索功能域 · 收藏访问端口。
//
// 页面只读取此端口查询收藏状态；具体实现由 data 层适配器完成。
// 不直连 LearningFavoritesState（跨 feature presentation 违规）。

/// 收藏状态的只读 / 操作端口。
abstract interface class FavoritesAccessor {
  /// 该单词是否已收藏。
  bool isFavorite(String word);

  /// 切换收藏状态，返回切换后的收藏状态。
  Future<bool> toggle(String word);
}
