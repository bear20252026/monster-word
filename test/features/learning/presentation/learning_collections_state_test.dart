import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/features/learning/application/favorites_port.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/features/learning/application/mastered_words_reader.dart';
import 'package:word_app/features/learning/application/mastered_writer_port.dart';
import 'package:word_app/features/learning/presentation/learning_collections_state.dart';
import 'package:word_app/features/learning/presentation/learning_favorites_state.dart';
import 'package:word_app/features/learning/presentation/learning_mastered_state.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'favorite_words_v1': ['apple', 'banana'],
      'mastered_words_v1': ['cherry'],
    });
  });

  group('LearningCollectionsSnapshot', () {
    test('空快照为展示页面提供安全的零值默认值', () {
      const snapshot = LearningCollectionsSnapshot.empty();

      expect(snapshot.favoriteCount, 0);
      expect(snapshot.masteredCount, 0);
    });

    test('集合快照保留收藏与掌握计数', () {
      const snapshot = LearningCollectionsSnapshot(favoriteCount: 12, masteredCount: 37);

      expect(snapshot.favoriteCount, 12);
      expect(snapshot.masteredCount, 37);
    });
  });

  test('集合展示状态只组合收藏和手动掌握专用状态的当前快照', () async {
    final favorites = LearningFavoritesState(
      favoritesPort: _SharedPreferencesFavoritesPort(),
      queuePort: _EmptyQueuePort(),
    );
    final mastered = LearningMasteredState(
      masteredWordsReader: _SharedPreferencesMasteredWordsReader(),
      writerPort: _SharedPreferencesMasteredWriterPort(),
    );
    await Future.wait([favorites.refresh(), mastered.refresh()]);

    final collections = LearningCollectionsState()..synchronize(favorites: favorites, mastered: mastered);
    expect(collections.favoriteCount, 2);
    expect(collections.masteredCount, 1);

    await favorites.toggle('date');
    await mastered.toggle('elderberry');
    collections.synchronize(favorites: favorites, mastered: mastered);

    expect(collections.favoriteCount, 3);
    expect(collections.masteredCount, 2);
  });
}

class _SharedPreferencesFavoritesPort implements FavoritesPort {
  static const _key = 'favorite_words_v1';

  @override
  Future<Set<String>> getFavoriteWords() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  @override
  Future<void> toggleFavorite(String word) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_key) ?? const []).toSet();
    if (set.contains(word)) {
      set.remove(word);
    } else {
      set.add(word);
    }
    await prefs.setStringList(_key, set.toList());
  }

  @override
  bool isFavorite(String word) => false;
}

class _EmptyQueuePort implements LearningQueuePort {
  @override
  Future<List<Word>> loadBook(Book book, {int? limit, required bool shuffle}) async => const [];

  @override
  Future<List<Word>> loadFavoriteWords({required List<Word> currentQueue}) async => const [];
}

class _SharedPreferencesMasteredWordsReader implements MasteredWordsReader {
  static const _key = 'mastered_words_v1';

  @override
  Future<List<String>> loadTexts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  @override
  Future<List<Word>> loadWords() async {
    final texts = await loadTexts();
    return texts.map((w) => Word(word: w)).toList();
  }
}

class _SharedPreferencesMasteredWriterPort implements MasteredWriterPort {
  static const _key = 'mastered_words_v1';

  @override
  Future<void> toggleMastered(String word) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_key) ?? const []).toSet();
    if (set.contains(word)) {
      set.remove(word);
    } else {
      set.add(word);
    }
    await prefs.setStringList(_key, set.toList());
  }
}
