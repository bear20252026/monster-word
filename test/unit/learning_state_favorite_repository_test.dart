import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/repositories/fav_repository.dart';
import 'package:word_app/repositories/mastered_repository.dart';
import 'package:word_app/state/learning_state.dart';

class _FakeMasteredRepository implements MasteredRepository {
  _FakeMasteredRepository(Iterable<String> initialWords) : _words = {...initialWords};

  final Set<String> _words;

  @override
  Future<Set<String>> getMasteredWords() async => Set<String>.from(_words);

  @override
  bool isMastered(String word) => _words.contains(word);

  @override
  int get masteredCount => _words.length;

  @override
  Future<void> toggleMastered(String word) async {
    if (_words.contains(word)) {
      _words.remove(word);
    } else {
      _words.add(word);
    }
  }
}

class _FakeFavRepository implements FavRepository {
  _FakeFavRepository(Iterable<String> initialFavorites) : _favorites = {...initialFavorites};

  final Set<String> _favorites;

  @override
  Future<void> addFavorite(String word) async {
    _favorites.add(word);
  }

  @override
  int get favoriteCount => _favorites.length;

  @override
  int get favoriteSentenceCount => 0;

  @override
  Future<Set<String>> getFavoriteWords() async => Set<String>.from(_favorites);

  @override
  bool isFavorite(String word) => _favorites.contains(word);

  @override
  Future<void> removeFavorite(String word) async {
    _favorites.remove(word);
  }

  @override
  Future<void> toggleFavorite(String word) async {
    if (_favorites.contains(word)) {
      _favorites.remove(word);
    } else {
      _favorites.add(word);
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('LearningState 收藏状态统一委托给 FavRepository', () async {
    final favorites = _FakeFavRepository({'apple'});
    final mastered = _FakeMasteredRepository(const []);
    final state = LearningState(favRepository: favorites, masteredRepository: mastered);

    expect(state.isFavorite('apple'), isTrue);
    expect(state.favoriteCount, 1);

    final removed = await state.toggleFavorite('apple');
    expect(removed, isFalse);
    expect(favorites.isFavorite('apple'), isFalse);

    final added = await state.toggleFavorite('banana');
    expect(added, isTrue);
    expect(favorites.isFavorite('banana'), isTrue);
    expect(state.favoriteCount, 1);
  });

  test('LearningState 掌握标记统一委托给 MasteredRepository', () async {
    final mastered = _FakeMasteredRepository({'apple'});
    final state = LearningState(favRepository: _FakeFavRepository(const []), masteredRepository: mastered);

    expect(state.isMastered('apple'), isTrue);
    expect(state.masteredCount, 1);
    expect(state.masteredNum, 1);

    final removed = await state.toggleMastered('apple');
    expect(removed, isFalse);
    expect(mastered.isMastered('apple'), isFalse);

    final added = await state.toggleMastered('banana');
    expect(added, isTrue);
    expect(mastered.isMastered('banana'), isTrue);
    expect(state.masteredCount, 1);
  });
}
