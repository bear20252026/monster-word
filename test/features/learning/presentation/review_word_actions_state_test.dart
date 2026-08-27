import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/presentation/review_word_actions_state.dart';
import 'package:word_app/repositories/fav_repository.dart';
import 'package:word_app/repositories/mastered_repository.dart';

void main() {
  group('ReviewWordActionsState', () {
    test('同步真实收藏快照并持久化切换结果', () async {
      final favorites = _FakeFavRepository({'apple'});
      final state = ReviewWordActionsState(
        favRepository: favorites,
        masteredRepository: _FakeMasteredRepository(const {}),
      );

      await state.initialize();

      expect(state.initialized, isTrue);
      expect(state.isFavorite('apple'), isTrue);
      expect(await state.toggleFavorite('apple'), isFalse);
      expect(state.isFavorite('apple'), isFalse);
      expect(favorites.isFavorite('apple'), isFalse);
      expect(await state.toggleFavorite('banana'), isTrue);
      expect(state.isFavorite('banana'), isTrue);
      expect(favorites.isFavorite('banana'), isTrue);
    });

    test('手动掌握标记只添加一次，不会反转已掌握状态', () async {
      final mastered = _FakeMasteredRepository(const {});
      final state = ReviewWordActionsState(favRepository: _FakeFavRepository(const {}), masteredRepository: mastered);

      expect(await state.markManuallyMastered('reviewed'), isTrue);
      expect(state.isManuallyMastered('reviewed'), isTrue);
      expect(mastered.isMastered('reviewed'), isTrue);
      expect(await state.markManuallyMastered('reviewed'), isFalse);
      expect(mastered.toggleCalls, 1);
      expect(mastered.isMastered('reviewed'), isTrue);
    });
  });
}

class _FakeMasteredRepository implements MasteredRepository {
  _FakeMasteredRepository(Iterable<String> words) : _words = {...words};

  final Set<String> _words;
  int toggleCalls = 0;

  @override
  Future<Set<String>> getMasteredWords() async => Set<String>.from(_words);

  @override
  bool isMastered(String word) => _words.contains(word);

  @override
  int get masteredCount => _words.length;

  @override
  Future<void> toggleMastered(String word) async {
    toggleCalls++;
    if (_words.contains(word)) {
      _words.remove(word);
    } else {
      _words.add(word);
    }
  }
}

class _FakeFavRepository implements FavRepository {
  _FakeFavRepository(Iterable<String> words) : _words = {...words};

  final Set<String> _words;

  @override
  Future<void> addFavorite(String word) async {
    _words.add(word);
  }

  @override
  int get favoriteCount => _words.length;

  @override
  int get favoriteSentenceCount => 0;

  @override
  Future<Set<String>> getFavoriteWords() async => Set<String>.from(_words);

  @override
  bool isFavorite(String word) => _words.contains(word);

  @override
  Future<void> removeFavorite(String word) async {
    _words.remove(word);
  }

  @override
  Future<void> toggleFavorite(String word) async {
    if (_words.contains(word)) {
      _words.remove(word);
    } else {
      _words.add(word);
    }
  }

  @override
  Future<bool> addFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) async => false;

  @override
  Future<List<Map<String, dynamic>>> getFavoriteSentences() async => const [];

  @override
  Future<bool> isFavoriteSentence(int wordId, String sentenceId) async => false;

  @override
  Future<bool> removeFavoriteSentence(int wordId, String sentenceId) async => false;

  @override
  Future<bool> toggleFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) async => false;
}
