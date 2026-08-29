import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/quick_review/data/repository_quick_review_word_reader.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/repositories/word_repository.dart';

void main() {
  test('loads quick-review words using the existing repository ordering contract', () async {
    final repository = _FakeWordRepository([
      Word(id: 2, word: 'second'),
      Word(id: 9, word: 'ninth'),
      Word(id: 5, word: 'fifth'),
    ]);

    final reader = RepositoryQuickReviewWordReader(repository);
    final words = await reader.loadWords(limit: 2);

    expect(repository.lastQuery, '');
    expect(words.map((word) => word.id), [9, 5]);
  });
}

class _FakeWordRepository implements WordRepository {
  _FakeWordRepository(this.words);

  final List<Word> words;
  String? lastQuery;

  @override
  Future<Word?> getWordById(int id) async => null;

  @override
  Future<Word?> getWordByText(String text) async => null;

  @override
  Future<List<Word>> getWordsByBookId(int bookId, {int? limit, int? offset}) async => const [];

  @override
  Future<List<Word>> getWordsByIds(Iterable<int> ids) async => const [];

  @override
  Future<List<Word>> getWordsByTexts(Iterable<String> texts) async => const [];

  @override
  Future<Map<String, dynamic>?> getWordDetails(int wordId) async => null;

  @override
  Future<List<Word>> getRandomWords(int count, {int? excludeBookId}) async => const [];

  @override
  Future<List<Word>> searchWords(String query, {int? limit}) async {
    lastQuery = query;
    return List<Word>.of(words);
  }

  @override
  Future<int> updateWordStatus(int wordId, Map<String, dynamic> status) async => 1;
}
