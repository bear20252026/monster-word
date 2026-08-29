import 'package:word_app/core/repositories/fav_repository.dart';
import 'package:word_app/core/repositories/fav_repository_impl.dart';
import 'package:word_app/features/dictionary/application/dictionary_favorite_writer.dart';

/// 基于 FavRepository 的收藏操作适配器。
///
/// 实现 [DictionaryFavoriteWriter] 端口，封装收藏/取消收藏逻辑。
/// 委托给共享仓储 [FavRepository]，不引入其他 feature 内部依赖。
class ServiceDictionaryFavoriteWriter implements DictionaryFavoriteWriter {
  ServiceDictionaryFavoriteWriter({this._favRepository});

  final FavRepository? _favRepository;

  FavRepository get _fav =>
      _favRepository ?? FavRepositoryImpl();

  @override
  Future<bool> toggleFavorite(String word) async {
    if (word.trim().isEmpty) return false;
    final wasFav = _fav.isFavorite(word);
    await _fav.toggleFavorite(word);
    return !wasFav;
  }

  @override
  bool isFavorite(String word) => _fav.isFavorite(word);

  @override
  Future<Set<String>> getFavoriteWords() async {
    return _fav.getFavoriteWords();
  }
}
