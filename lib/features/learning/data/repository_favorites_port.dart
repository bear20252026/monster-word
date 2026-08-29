import 'package:word_app/core/di/service_locator.dart';
import 'package:word_app/core/repositories/fav_repository.dart';
import 'package:word_app/features/learning/application/favorites_port.dart';

/// Adapts [FavRepository] (legacy repositories) to [FavoritesPort] (application layer).
class RepositoryFavoritesPort implements FavoritesPort {
  final FavRepository _repository;

  RepositoryFavoritesPort(this._repository);

  factory RepositoryFavoritesPort.fromServiceLocator() =>
      RepositoryFavoritesPort(sl<FavRepository>());

  @override
  Future<Set<String>> getFavoriteWords() => _repository.getFavoriteWords();

  @override
  Future<void> toggleFavorite(String word) => _repository.toggleFavorite(word);

  @override
  bool isFavorite(String word) => _repository.isFavorite(word);
}
