import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/data/learning_queue_repository.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/core/repositories/fav_repository.dart';

void main() {
  group('LearningQueueRepository', () {
    test('词书加载保留上限、起始偏移和关闭乱序时的原始顺序', () async {
      final source = _FakeWordSource(
        bookWords: [
          Word(id: 1, word: 'first'),
          Word(id: 2, word: 'second'),
        ],
      );
      final repository = LearningQueueRepository(wordSource: source, favRepository: _FakeFavRepository());
      final book = Book(id: 11, code: 'CET4', name: '四级', wordCount: 2);

      final queue = await repository.loadBook(book, limit: 50, shuffle: false);

      expect(source.requestedBookId, 11);
      expect(source.requestedLimit, 50);
      expect(source.requestedOffset, 0);
      expect(queue.map((word) => word.word), ['first', 'second']);
    });

    test('收藏词在全库未解析到词条时回退当前学习队列', () async {
      final source = _FakeWordSource();
      final repository = LearningQueueRepository(
        wordSource: source,
        favRepository: _FakeFavRepository(favorites: {'saved'}),
      );

      final words = await repository.loadFavoriteWords(
        currentQueue: [
          Word(word: 'other'),
          Word(word: 'saved'),
        ],
      );

      expect(words.map((word) => word.word), ['saved']);
      expect(source.requestedNames, {'saved'});
    });
  });
}

class _FakeWordSource implements LearningQueueWordSource {
  _FakeWordSource({List<Word>? bookWords, List<Word>? namedWords})
    : _bookWords = bookWords ?? const [],
      _namedWords = namedWords ?? const [];

  final List<Word> _bookWords;
  final List<Word> _namedWords;
  int? requestedBookId;
  int? requestedLimit;
  int? requestedOffset;
  Set<String>? requestedNames;

  @override
  Future<List<Word>> getWordsByBook(int bookId, {required int limit, required int offset}) async {
    requestedBookId = bookId;
    requestedLimit = limit;
    requestedOffset = offset;
    return List<Word>.from(_bookWords);
  }

  @override
  Future<List<Word>> getWordsByNames(Iterable<String> words) async {
    requestedNames = words.toSet();
    return List<Word>.from(_namedWords);
  }
}

class _FakeFavRepository implements FavRepository {
  _FakeFavRepository({Set<String>? favorites}) : _favorites = favorites ?? {};

  final Set<String> _favorites;

  @override
  Future<void> addFavorite(String word) async => _favorites.add(word);

  @override
  int get favoriteCount => _favorites.length;

  @override
  int get favoriteSentenceCount => 0;

  @override
  Future<Set<String>> getFavoriteWords() async => Set<String>.from(_favorites);

  @override
  bool isFavorite(String word) => _favorites.contains(word);

  @override
  Future<void> removeFavorite(String word) async => _favorites.remove(word);

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
