import 'package:flutter/foundation.dart';

/// 收藏单词状态的跨 feature 共享契约（core 层，单向依赖）。
///
/// 由 learning 模块的展示状态实现（见
/// `lib/features/learning/presentation/learning_favorites_state.dart`），并经由
/// learning feature scope 以 `LearningFavoritesStore` 类型暴露。
///
/// 装配约定：search / book 等消费方只依赖本契约（`lib/core/learning`），不再
/// import learning/presentation 的具体状态类型；规则同
/// `LearningProgressReader` (G3)。
abstract class LearningFavoritesStore extends ChangeNotifier {
  /// 当前收藏的词形（不可变视图）。
  Set<String> get favoriteWords;

  /// 收藏数量。
  int get favoriteCount;

  /// 是否正在从仓储加载收藏词表。
  bool get isLoading;

  /// 单词是否处于收藏中。
  bool isFavorite(String word);

  /// 重新从仓储加载收藏词表。
  Future<void> refresh();

  /// 切换某个单词的收藏状态，返回切换后是否仍为收藏。
  Future<bool> toggle(String word);
}
