// 搜索功能域 · 收藏访问适配器。
//
// 通过 LearningFavoritesState（learning feature presentation 层）实现收藏操作，
// 但该引用仅在 data 适配器层；presentation 页面只依赖 FavoritesAccessor 端口。

import '../../learning/presentation/learning_favorites_state.dart';
import '../application/favorites_accessor.dart';

/// 将 LearningFavoritesState 适配为 FavoritesAccessor 端口。
class FavoritesAccessorAdapter implements FavoritesAccessor {
  final LearningFavoritesState _favorites;

  const FavoritesAccessorAdapter(this._favorites);

  @override
  bool isFavorite(String word) => _favorites.isFavorite(word);

  @override
  Future<bool> toggle(String word) => _favorites.toggle(word);
}
