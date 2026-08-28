import '../../../models/sentence_models.dart';
import '../../../repositories/fav_repository.dart';
import '../application/sentence_favorites_store.dart';

/// 基于既有收藏仓储的例句收藏适配器。
///
/// 适配器不保存额外收藏状态，确保 [FavRepository] 继续是唯一持久化事实来源。
class RepositorySentenceFavoritesStore implements SentenceFavoritesStore {
  RepositorySentenceFavoritesStore({required this._repository});

  final FavRepository _repository;

  @override
  Future<List<FavSentenceData>> list() async {
    final records = await _repository.getFavoriteSentences();
    return records.map(_toFavoriteSentence).toList(growable: false);
  }

  FavSentenceData _toFavoriteSentence(Map<String, dynamic> record) {
    final rawSentence = record['sentenceData'];
    final sentenceData = rawSentence is SentenceData
        ? rawSentence
        : rawSentence is Map<String, dynamic>
        ? SentenceData.fromJson(rawSentence)
        : null;
    return FavSentenceData(
      word: record['word'] as String? ?? '',
      wordId: (record['wordId'] as num?)?.toInt() ?? 0,
      sentenceId: record['sentenceId'] as String? ?? '',
      sentenceData: sentenceData,
      wordUsage: record['wordUsage'] as String? ?? '',
      updateTime: record['updateTime'] as String? ?? '20990101010101',
      type: (record['type'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<bool> remove({required int wordId, required String sentenceId}) {
    return _repository.removeFavoriteSentence(wordId, sentenceId);
  }

  @override
  Future<bool> isFavorite({required int wordId, required String sentenceId}) {
    return _repository.isFavoriteSentence(wordId, sentenceId);
  }

  @override
  Future<bool> toggle({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) {
    return _repository.toggleFavoriteSentence(
      wordId: wordId,
      sentenceId: sentenceId,
      english: english,
      chinese: chinese,
      source: source,
    );
  }
}
