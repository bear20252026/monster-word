/// Port: favorites CRUD.
/// Presentation states depend on this abstraction, not on
/// `lib/repositories/fav_repository.dart` directly.
abstract class FavoritesPort {
  Future<Set<String>> getFavoriteWords();

  Future<void> toggleFavorite(String word);

  bool isFavorite(String word);
}
