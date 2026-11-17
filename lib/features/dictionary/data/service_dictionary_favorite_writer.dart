import 'package:word_app/features/dictionary/application/dictionary_favorite_writer.dart';
import 'package:word_app/features/learning/application/learning_favorites_store.dart';

/// 基于 LearningFavoritesStore 的收藏操作适配器。
///
/// 实现 [DictionaryFavoriteWriter] 端口，封装收藏/取消收藏逻辑。
///
/// 第四轮审计 M1（2026-11-17）：写路径统一经共享状态源 [LearningFavoritesStore]
/// （learning 域经 application 契约暴露，组合根注入同一实例）。此前本适配器
/// 直写 FavRepository（DB 事实源），绕过 learning/search/book/content 各域消费的
/// 内存快照且无任何刷新调用——词典页收藏后其他域星标陈旧（与 I34 生词缓存
/// 同族缺陷，收藏侧漏网）。经 Store.toggle 后快照同步 + notifyListeners，
/// 各域 watch/select 即时刷新。
class ServiceDictionaryFavoriteWriter implements DictionaryFavoriteWriter {
  ServiceDictionaryFavoriteWriter({required LearningFavoritesStore favoritesStore}) : _store = favoritesStore;

  final LearningFavoritesStore _store;

  @override
  Future<bool> toggleFavorite(String word) async {
    if (word.trim().isEmpty) return false;
    return _store.toggle(word);
  }

  @override
  bool isFavorite(String word) => _store.isFavorite(word);

  @override
  Future<Set<String>> getFavoriteWords() async {
    // 快照即事实视图（Store 构造期已 refresh；写路径同源维护）。
    return _store.favoriteWords;
  }
}
