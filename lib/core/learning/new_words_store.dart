import 'package:flutter/foundation.dart';

import '../../models/word.dart';

/// 生词本状态的跨 feature 共享契约（core 层，单向依赖）。
///
/// 由 learning 模块的展示状态实现（见
/// `lib/features/learning/presentation/new_words_state.dart`），并经由 learning
/// feature scope 以 `NewWordsStore` 类型暴露。规则同 `LearningProgressReader` (G3)。
///
/// 消费方（如 book 的词卡徽标）只依赖本契约，不 import learning/presentation。
abstract class NewWordsStore extends ChangeNotifier {
  /// 是否已从仓储初始化过生词集合。
  bool get initialized;

  /// 当前生词数量。
  int get count;

  /// 某单词（按 id）是否在生词本中。
  bool isNewWord(int wordId);

  /// 从仓储加载生词集合（幂等，首次调用生效）。
  Future<void> initialize();

  /// 切换某单词的生词状态，并可记录来源，返回切换后是否处于生词本。
  Future<void> toggleNewWord(Word word, {String source = 'manual'});
}
