import 'package:word_app/models/sentence_models.dart';

/// 词条浏览流程所需的例句收藏能力。
///
/// [sentenceId] 由展示层根据既有规则生成；该端口只负责读取或切换收藏状态。
abstract interface class SentenceFavoritesStore {
  Future<List<FavSentenceData>> list();

  /// MEM/U3+分页：按更新时间倒序分页读取（句库页窗口化）。
  Future<List<FavSentenceData>> listPage({required int limit, int offset = 0});

  /// 收藏例句总数（不加载载荷）。
  Future<int> count();

  Future<bool> remove({required int wordId, required String sentenceId});

  /// 审计 I19：批量取消收藏（单事务），返回实际移除条数。
  Future<int> removeBatch({required List<({int wordId, String sentenceId})> items});

  Future<bool> isFavorite({required int wordId, required String sentenceId});

  /// 审计 I35：[word] 为例句所属单词文本（列表页展示语义）。
  Future<bool> toggle({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
    String word = '',
  });
}
