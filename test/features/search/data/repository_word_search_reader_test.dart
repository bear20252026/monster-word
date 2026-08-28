import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/search/data/repository_word_search_reader.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/repositories/word_repository.dart';

void main() {
  test('delegates query and limit to the existing word repository', () async {
    final results = [Word(id: 1, word: 'search')];
    final repository = _FakeWordRepository(results: results);
    final reader = RepositoryWordSearchReader(repository: repository);

    expect(await reader.search('search', limit: 12), same(results));
    expect(repository.lastQuery, 'search');
    expect(repository.lastLimit, 12);
  });
}

class _FakeWordRepository implements WordRepository {
  _FakeWordRepository({required this.results});

  final List<Word> results;
  String? lastQuery;
  int? lastLimit;

  @override
  Future<List<Word>> getWordsByBookId(int bookId, {int? limit, int? offset}) => throw UnimplementedError();

  @override
  Future<Word?> getWordById(int id) => throw UnimplementedError();

  @override
  Future<Word?> getWordByText(String text) => throw UnimplementedError();

  @override
  Future<List<Word>> getWordsByTexts(Iterable<String> texts) => throw UnimplementedError();

  @override
  Future<List<Word>> getWordsByIds(Iterable<int> ids) => throw UnimplementedError();

  @override
  Future<List<Word>> searchWords(String query, {int? limit}) async {
    lastQuery = query;
    lastLimit = limit;
    return results;
  }

  @override
  Future<Map<String, dynamic>?> getWordDetails(int wordId) => throw UnimplementedError();

  @override
  Future<List<Word>> getRandomWords(int count, {int? excludeBookId}) => throw UnimplementedError();

  @override
  Future<int> updateWordStatus(int wordId, Map<String, dynamic> status) => throw UnimplementedError();
}
