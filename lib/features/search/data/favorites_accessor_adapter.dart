// 搜索功能域 · 收藏访问适配器。
//
// 通过 LearningFavoritesStore（learning 经 core 契约暴露）实现收藏操作，
// 该引用仅在 data 适配器层；presentation 页面只依赖 FavoritesAccessor 端口。

import 'package:word_app/features/learning/application/learning_favorites_store.dart';
import 'package:word_app/features/search/application/favorites_accessor.dart';

/// 将 LearningFavoritesStore（core 契约）适配为 FavoritesAccessor 端口。
class FavoritesAccessorAdapter implements FavoritesAccessor {
  final LearningFavoritesStore _favorites;

  const FavoritesAccessorAdapter(this._favorites);

  @override
  bool isFavorite(String word) => _favorites.isFavorite(word);

  @override
  Future<bool> toggle(String word) => _favorites.toggle(word);
}
