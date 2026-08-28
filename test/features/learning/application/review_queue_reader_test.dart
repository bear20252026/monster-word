import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/learning/application/review_queue_reader.dart';
import 'package:word_app/features/learning/data/repository_review_queue_reader.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/repositories/word_repository.dart';

void main() {
  group('ReviewQueueReader', () {
    test('优先返回 FSRS 到期词且不查询词库', () async {
      final dueWord = Word(id: 1, word: 'due');
      final repository = _FakeWordRepository();
      final reader = RepositoryReviewQueueReader(wordRepository: repository);

      final words = await reader.loadWords(
        ReviewQueueSnapshot(
          dueWords: [dueWord],
          queueWords: [Word(id: 2, word: 'queued')],
        ),
      );

      expect(words, equals([dueWord]));
      expect(repository.queries, isEmpty);
    });

    test('没有到期词时返回当前学习队列且不查询词库', () async {
      final queuedWord = Word(id: 2, word: 'queued');
      final repository = _FakeWordRepository();
      final reader = RepositoryReviewQueueReader(wordRepository: repository);

      final words = await reader.loadWords(ReviewQueueSnapshot(dueWords: const [], queueWords: [queuedWord]));

      expect(words, equals([queuedWord]));
      expect(repository.queries, isEmpty);
    });

    test('空状态先查询 a 样本，空结果再查询 the 样本', () async {
      final fallbackWord = Word(id: 3, word: 'the');
      final repository = _FakeWordRepository(theWords: [fallbackWord]);
      final reader = RepositoryReviewQueueReader(wordRepository: repository);

      final words = await reader.loadWords(const ReviewQueueSnapshot.empty());

      expect(words, equals([fallbackWord]));
      expect(repository.queries, ['a', 'the']);
    });

    test('a 样本存在时不执行第二次回退查询', () async {
      final sampleWord = Word(id: 4, word: 'apple');
      final repository = _FakeWordRepository(aWords: [sampleWord]);
      final reader = RepositoryReviewQueueReader(wordRepository: repository);

      final words = await reader.loadWords(const ReviewQueueSnapshot.empty());

      expect(words, equals([sampleWord]));
      expect(repository.queries, ['a']);
    });
  });
}

class _FakeWordRepository implements WordRepository {
  _FakeWordRepository({this.aWords = const [], this.theWords = const []});

  final List<Word> aWords;
  final List<Word> theWords;
  final List<String> queries = [];

  @override
  Future<List<Word>> searchWords(String query, {int? limit}) async {
    queries.add(query);
    return switch (query) {
      'a' => aWords,
      'the' => theWords,
      _ => const [],
    };
  }

  @override
  Future<Word?> getWordById(int id) => throw UnimplementedError();

  @override
  Future<Word?> getWordByText(String text) => throw UnimplementedError();

  @override
  Future<List<Word>> getWordsByBookId(int bookId, {int? limit, int? offset}) => throw UnimplementedError();

  @override
  Future<List<Word>> getWordsByIds(Iterable<int> ids) => throw UnimplementedError();

  @override
  Future<List<Word>> getWordsByTexts(Iterable<String> texts) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>?> getWordDetails(int wordId) => throw UnimplementedError();

  @override
  Future<List<Word>> getRandomWords(int count, {int? excludeBookId}) => throw UnimplementedError();

  @override
  Future<int> updateWordStatus(int wordId, Map<String, dynamic> status) => throw UnimplementedError();
}
