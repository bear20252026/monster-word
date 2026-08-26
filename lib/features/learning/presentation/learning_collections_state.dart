import 'package:flutter/foundation.dart';

import '../../../state/learning_state.dart';

/// 收藏与掌握标记的不可变展示快照。
///
/// 该模型只服务数量、徽章和空态等展示需求，不承载收藏写入或词表查询，
/// 以避免在当前迁移阶段改变既有 SharedPreferences 与仓储写入语义。
class LearningCollectionsSnapshot {
  const LearningCollectionsSnapshot({required this.favoriteCount, required this.masteredCount});

  const LearningCollectionsSnapshot.empty() : favoriteCount = 0, masteredCount = 0;

  factory LearningCollectionsSnapshot.fromLegacy(LearningState legacy) {
    return LearningCollectionsSnapshot(favoriteCount: legacy.favoriteCount, masteredCount: legacy.masteredCount);
  }

  final int favoriteCount;
  final int masteredCount;
}

/// 收藏与掌握标记的过渡展示状态。
///
/// 当前由 [LearningState] 同步，以保持现有页面展示的数据来源不变。将来收藏
/// 与掌握标记的读写存储完成统一后，仅替换此适配器的数据来源；展示页面不应
/// 重新直接依赖遗留状态。
class LearningCollectionsState extends ChangeNotifier {
  LearningCollectionsSnapshot _snapshot = const LearningCollectionsSnapshot.empty();

  LearningCollectionsSnapshot get snapshot => _snapshot;

  int get favoriteCount => _snapshot.favoriteCount;

  int get masteredCount => _snapshot.masteredCount;

  void synchronizeFrom(LearningState legacy) {
    _snapshot = LearningCollectionsSnapshot.fromLegacy(legacy);
    notifyListeners();
  }
}
