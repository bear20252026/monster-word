/// 词条浏览流程所需的例句收藏能力。
///
/// [sentenceId] 由展示层根据既有规则生成；该端口只负责读取或切换收藏状态。
abstract interface class SentenceFavoritesStore {
  Future<bool> isFavorite({required int wordId, required String sentenceId});

  Future<bool> toggle({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  });
}
