import 'package:flutter/foundation.dart';

/// 收藏 / 掌握数量的跨 feature 共享只读契约（core 层，单向依赖）。
///
/// 由 learning 模块的聚合展示状态实现（见
/// `lib/features/learning/presentation/learning_collections_state.dart`），并经由
/// learning feature scope 以 `LearningCollectionsReader` 类型暴露。
///
/// 装配约定：content 等消费方（如 `my_content_page`、`word_browse/foot_mark_page`）
/// 只依赖本契约读取数量、徽章与空态所需字段，不再 import learning/presentation 的
/// 具体聚合状态；规则同 `LearningFavoritesStore` / `LearningProgressReader`。
abstract class LearningCollectionsReader extends ChangeNotifier {
  /// 收藏单词数量。
  int get favoriteCount;

  /// 已掌握单词数量。
  int get masteredCount;
}
