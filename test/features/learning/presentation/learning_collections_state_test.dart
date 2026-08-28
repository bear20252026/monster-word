import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/features/learning/application/mastered_words_reader.dart';
import 'package:word_app/features/learning/data/learning_queue_repository.dart';
import 'package:word_app/features/learning/presentation/learning_collections_state.dart';
import 'package:word_app/features/learning/presentation/learning_favorites_state.dart';
import 'package:word_app/features/learning/presentation/learning_mastered_state.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/repositories/fav_repository_impl.dart';
import 'package:word_app/repositories/mastered_repository_impl.dart';

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
    final favoriteRepository = FavRepositoryImpl();
    final favorites = LearningFavoritesState(
      favoriteRepository: favoriteRepository,
      queueRepository: LearningQueueRepository(wordSource: _UnusedQueueWordSource(), favRepository: favoriteRepository),
    );
    final masteredRepository = MasteredRepositoryImpl();
    final mastered = LearningMasteredState(
      masteredWordsReader: _FakeMasteredWordsReader(masteredRepository),
      masteredRepository: masteredRepository,
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

class _FakeMasteredWordsReader implements MasteredWordsReader {
  _FakeMasteredWordsReader(this.repository);

  final MasteredRepository repository;

  @override
  Future<List<String>> loadTexts() async => (await repository.getMasteredWords()).toList();

  @override
  Future<List<Word>> loadWords() async => const [];
}

class _UnusedQueueWordSource implements LearningQueueWordSource {
  @override
  Future<List<Word>> getWordsByBook(int bookId, {required int limit, required int offset}) async => const [];

  @override
  Future<List<Word>> getWordsByNames(Iterable<String> words) async => const [];
}
