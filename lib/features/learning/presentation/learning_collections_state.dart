import 'package:flutter/foundation.dart';

import 'learning_favorites_state.dart';
import 'learning_mastered_state.dart';

/// 收藏与掌握标记的不可变展示快照。
///
/// 该模型只服务数量、徽章和空态等展示需求；词条持久化仍由各自仓储和专用状态负责。
class LearningCollectionsSnapshot {
  const LearningCollectionsSnapshot({required this.favoriteCount, required this.masteredCount});

  const LearningCollectionsSnapshot.empty() : favoriteCount = 0, masteredCount = 0;

  factory LearningCollectionsSnapshot.fromStates({
    required LearningFavoritesState favorites,
    required LearningMasteredState mastered,
  }) {
    return LearningCollectionsSnapshot(favoriteCount: favorites.favoriteCount, masteredCount: mastered.masteredCount);
  }

  final int favoriteCount;
  final int masteredCount;
}

/// 收藏与掌握标记的聚合展示状态。
///
/// 页面依赖此状态以读取数量，而收藏与掌握词的写入分别走专用状态，避免形成新的
/// 持久化或可变集合事实来源。
class LearningCollectionsState extends ChangeNotifier {
  LearningCollectionsSnapshot _snapshot = const LearningCollectionsSnapshot.empty();

  LearningCollectionsSnapshot get snapshot => _snapshot;
  int get favoriteCount => _snapshot.favoriteCount;
  int get masteredCount => _snapshot.masteredCount;

  void synchronize({required LearningFavoritesState favorites, required LearningMasteredState mastered}) {
    _snapshot = LearningCollectionsSnapshot.fromStates(favorites: favorites, mastered: mastered);
    notifyListeners();
  }
}
