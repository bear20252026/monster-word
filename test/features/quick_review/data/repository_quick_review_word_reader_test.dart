import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/quick_review/data/repository_quick_review_word_reader.dart';
import 'package:word_app/features/quick_review/domain/exam_type.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/core/repositories/word_repository.dart';

void main() {
  test('速刷词源走全库随机取样，不再字母序头部（2026-11-14）', () async {
    final repository = _FakeWordRepository([
      Word(id: 2, word: 'second'),
      Word(id: 9, word: 'ninth'),
      Word(id: 5, word: 'fifth'),
    ]);

    final reader = RepositoryQuickReviewWordReader(repository);
    final words = await reader.loadWords(limit: 2);

    expect(repository.lastRandomCount, 2);
    expect(words.map((word) => word.id), [2, 9]);
  });

  group('审计 R12：按考试词书取词', () {
    final cet4Book = Book(id: 11, code: 'CET4DGCH', name: '四级词汇', wordCount: 3);
    final gaokaoBook = Book(id: 22, code: 'GAOKAO', name: '高考词汇', wordCount: 2);
    final petsBook = Book(id: 33, code: 'PETS4', name: '公共英语四级', wordCount: 2);

    test('匹配考试词书：从书内取词（释义非空），不走全库随机', () async {
      final repository = _FakeWordRepository([Word(id: 1, word: 'random')]);
      repository.bookWords[11] = [
        Word(id: 101, word: 'abandon', interpret: '放弃'),
        Word(id: 102, word: 'ability', interpret: '能力'),
        Word(id: 103, word: 'empty', interpret: ''), // 空壳词过滤
      ];
      final reader = RepositoryQuickReviewWordReader(
        repository,
        catalog: _FakeCatalog([cet4Book, gaokaoBook, petsBook]),
      );

      expect(await reader.hasExamBooks(ExamType.cet4), isTrue);
      final words = await reader.loadWords(limit: 50, examType: ExamType.cet4);
      expect(repository.lastRandomCount, isNull, reason: '有匹配词书不得回退全库随机');
      expect(repository.lastBookId, 11);
      expect(words.map((w) => w.id).toSet(), {101, 102});
    });

    test('PETS4（公共英语四级）不误配 CET4', () async {
      final reader = RepositoryQuickReviewWordReader(_FakeWordRepository(const []), catalog: _FakeCatalog([petsBook]));
      expect(await reader.hasExamBooks(ExamType.cet4), isFalse);
    });

    test('无匹配词书：回退全库随机且 hasExamBooks=false（UI 诚实提示）', () async {
      final repository = _FakeWordRepository([Word(id: 7, word: 'ielts_only')]);
      final reader = RepositoryQuickReviewWordReader(repository, catalog: _FakeCatalog([cet4Book]));
      expect(await reader.hasExamBooks(ExamType.ielts), isFalse);
      final words = await reader.loadWords(limit: 3, examType: ExamType.ielts);
      expect(repository.lastRandomCount, 3);
      expect(words.single.id, 7);
    });

    test('未注入目录（旧装配）：行为等同全库随机', () async {
      final repository = _FakeWordRepository([Word(id: 8, word: 'x')]);
      final reader = RepositoryQuickReviewWordReader(repository);
      expect(await reader.hasExamBooks(ExamType.cet4), isFalse);
      await reader.loadWords(limit: 2, examType: ExamType.cet4);
      expect(repository.lastRandomCount, 2);
    });
  });
}

class _FakeCatalog implements BookCatalogReader {
  _FakeCatalog(this.books);
  final List<Book> books;

  @override
  Future<List<Book>> listBooks() async => books;

  @override
  Future<Book?> findById(int bookId) async => books.where((b) => b.id == bookId).firstOrNull;
}

class _FakeWordRepository implements WordRepository {
  _FakeWordRepository(this.words);

  final List<Word> words;
  String? lastQuery;
  int? lastRandomCount;
  int? lastBookId;
  final Map<int, List<Word>> bookWords = {};

  @override
  Future<Word?> getWordById(int id) async => null;

  @override
  Future<Word?> getWordByText(String text) async => null;

  @override
  Future<List<Word>> getWordsByBookId(int bookId, {int? limit, int? offset}) async {
    lastBookId = bookId;
    return bookWords[bookId] ?? const [];
  }

  @override
  Future<List<Word>> getWordsByIds(Iterable<int> ids) async => const [];

  @override
  Future<List<Word>> getWordsByTexts(Iterable<String> texts) async => const [];

  @override
  Future<Map<String, dynamic>?> getWordDetails(int wordId) async => null;

  @override
  Future<List<Word>> getRandomWords(int count, {int? excludeBookId}) async {
    lastRandomCount = count;
    return words.take(count).toList();
  }

  @override
  Future<List<Word>> searchWords(String query, {int? limit}) async {
    lastQuery = query;
    return List<Word>.of(words);
  }
}
