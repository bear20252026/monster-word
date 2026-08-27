import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/application/book_words_reader.dart';
import 'package:word_app/features/learning/application/mastered_words_reader.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/repositories/mastered_repository.dart';
import 'package:word_app/repositories/word_repository.dart';

class _FakeMasteredRepository implements MasteredRepository {
  _FakeMasteredRepository(this._words);

  final Set<String> _words;

  @override
  Future<Set<String>> getMasteredWords() async => Set<String>.from(_words);

  @override
  bool isMastered(String word) => _words.contains(word);

  @override
  int get masteredCount => _words.length;

  @override
  Future<void> toggleMastered(String word) async {}
}

class _FakeWordRepository implements WordRepository {
  Iterable<String>? requestedTexts;
  int? requestedBookId;
  int? requestedBookLimit;

  @override
  Future<List<Word>> getWordsByTexts(Iterable<String> texts) async {
    requestedTexts = texts.toList();
    return [];
  }

  @override
  Future<Word?> getWordById(int id) => throw UnimplementedError();

  @override
  Future<Word?> getWordByText(String text) => throw UnimplementedError();

  @override
  Future<List<Word>> getWordsByBookId(int bookId, {int? limit, int? offset}) async {
    requestedBookId = bookId;
    requestedBookLimit = limit;
    return [];
  }

  @override
  Future<List<Word>> getRandomWords(int count, {int? excludeBookId}) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>?> getWordDetails(int wordId) => throw UnimplementedError();

  @override
  Future<List<Word>> searchWords(String query, {int? limit}) => throw UnimplementedError();

  @override
  Future<int> updateWordStatus(int wordId, Map<String, dynamic> status) => throw UnimplementedError();
}

void main() {
  test('已掌握标记为空时不查询单词仓储', () async {
    final wordRepository = _FakeWordRepository();
    final reader = MasteredWordsReader(masteredRepository: _FakeMasteredRepository({}), wordRepository: wordRepository);

    expect(await reader.loadWords(), isEmpty);
    expect(wordRepository.requestedTexts, isNull);
  });

  test('词书读取器保留词书编号与列表加载上限', () async {
    final wordRepository = _FakeWordRepository();
    final reader = BookWordsReader(wordRepository: wordRepository);

    expect(await reader.loadWords(42), isEmpty);
    expect(wordRepository.requestedBookId, 42);
    expect(wordRepository.requestedBookLimit, 1000);
  });

  test('已掌握标记通过单词仓储批量解析', () async {
    final wordRepository = _FakeWordRepository();
    final reader = MasteredWordsReader(
      masteredRepository: _FakeMasteredRepository({'apple', 'banana'}),
      wordRepository: wordRepository,
    );

    await reader.loadWords();

    expect(wordRepository.requestedTexts, containsAll(<String>['apple', 'banana']));
  });
}
