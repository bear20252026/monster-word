import '../../../repositories/fav_repository.dart';
import '../application/sentence_favorites_store.dart';

/// 基于既有收藏仓储的例句收藏适配器。
///
/// 适配器不保存额外收藏状态，确保 [FavRepository] 继续是唯一持久化事实来源。
class RepositorySentenceFavoritesStore implements SentenceFavoritesStore {
  RepositorySentenceFavoritesStore({required FavRepository repository}) : _repository = repository;

  final FavRepository _repository;

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
