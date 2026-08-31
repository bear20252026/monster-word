import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/application/learning_favorites_store.dart';
import 'package:word_app/features/search/data/favorites_accessor_adapter.dart';
import 'package:word_app/models/word.dart';

/// 模拟 learning 侧经 core 契约暴露的收藏存储。
///
/// 该 fake 只依赖 `LearningFavoritesStore`（core），不 import
/// learning/presentation —— 验证 WS-6 后 search/data 不再耦合 learning 展示层。
class _FakeFavoritesStore extends ChangeNotifier implements LearningFavoritesStore {
  _FakeFavoritesStore([Set<String>? init]) : _words = Set.of(init ?? const ['aaa', 'bbb']);

  final Set<String> _words;

  @override
  Set<String> get favoriteWords => Set.unmodifiable(_words);

  @override
  int get favoriteCount => _words.length;

  @override
  bool get isLoading => false;

  @override
  bool isFavorite(String word) => _words.contains(word);

  @override
  Future<void> refresh() async {}

  @override
  Future<List<Word>> loadFavoriteWords({required Iterable<Word> currentQueue}) async {
    return currentQueue.where((w) => _words.contains(w.word)).toList();
  }

  @override
  Future<bool> toggle(String word) async {
    if (_words.contains(word)) {
      _words.remove(word);
      return false;
    }
    _words.add(word);
    return true;
  }
}

void main() {
  group('FavoritesAccessorAdapter (WS-6 core-contract decoupling)', () {
    test('delegates isFavorite to the LearningFavoritesStore contract', () {
      final accessor = FavoritesAccessorAdapter(_FakeFavoritesStore());
      expect(accessor.isFavorite('aaa'), isTrue);
      expect(accessor.isFavorite('zzz'), isFalse);
    });

    test('delegates toggle and reflects the new state', () async {
      final store = _FakeFavoritesStore();
      final accessor = FavoritesAccessorAdapter(store);

      expect(await accessor.toggle('zzz'), isTrue);
      expect(accessor.isFavorite('zzz'), isTrue);

      expect(await accessor.toggle('zzz'), isFalse);
      expect(accessor.isFavorite('zzz'), isFalse);
    });
  });
}
