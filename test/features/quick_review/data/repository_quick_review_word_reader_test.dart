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
      Word(id: 2, word: 'second', interpret: '第二'),
      Word(id: 9, word: 'ninth', interpret: '第九'),
      Word(id: 5, word: 'fifth', interpret: '第五'),
    ]);

    final reader = RepositoryQuickReviewWordReader(repository);
    final words = await reader.loadWords(limit: 2);

    // 第三轮 T18：回退路径多取一倍候选再过滤空壳截断。
    expect(repository.lastRandomCount, 4);
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
      final repository = _FakeWordRepository([Word(id: 7, word: 'ielts_only', interpret: '雅思词')]);
      final reader = RepositoryQuickReviewWordReader(repository, catalog: _FakeCatalog([cet4Book]));
      expect(await reader.hasExamBooks(ExamType.ielts), isFalse);
      final result = await reader.loadWordsWithSource(limit: 3, examType: ExamType.ielts);
      expect(repository.lastRandomCount, 6); // T18：limit*2 候选
      expect(result.words.single.id, 7);
      expect(result.fromExamBook, isFalse);
    });

    test('未注入目录（旧装配）：行为等同全库随机', () async {
      final repository = _FakeWordRepository([Word(id: 8, word: 'x', interpret: '某释义')]);
      final reader = RepositoryQuickReviewWordReader(repository);
      expect(await reader.hasExamBooks(ExamType.cet4), isFalse);
      await reader.loadWords(limit: 2, examType: ExamType.cet4);
      expect(repository.lastRandomCount, 4); // T18：limit*2 候选
    });

    test('第三轮 T5：专业四级（TEM4）不误配 CET4', () async {
      final temBook = Book(id: 44, code: 'TEM4', name: '专业四级词汇', wordCount: 2);
      final reader = RepositoryQuickReviewWordReader(_FakeWordRepository(const []), catalog: _FakeCatalog([temBook]));
      expect(await reader.hasExamBooks(ExamType.cet4), isFalse);
      // 中文名「专四」同样排除。
      final temBook2 = Book(id: 45, code: 'ZY4', name: '专四核心', wordCount: 2);
      final reader2 = RepositoryQuickReviewWordReader(_FakeWordRepository(const []), catalog: _FakeCatalog([temBook2]));
      expect(await reader2.hasExamBooks(ExamType.cet4), isFalse);
    });

    test('第三轮 T18：纯英文释义空壳词被过滤（书内与回退路径同口径）', () async {
      final repository = _FakeWordRepository([
        Word(id: 201, word: 'english_only', interpret: 'pure english definition'),
        Word(id: 202, word: 'has_cn', interpret: '有中文'),
      ]);
      repository.bookWords[11] = [
        Word(id: 101, word: 'en_only', interpret: 'no chinese here'),
        Word(id: 102, word: 'cn_ok', interpret: '中文释义'),
      ];
      final reader = RepositoryQuickReviewWordReader(repository, catalog: _FakeCatalog([cet4Book]));
      final fromBook = await reader.loadWordsWithSource(limit: 50, examType: ExamType.cet4);
      expect(fromBook.words.map((w) => w.id), [102], reason: '书内纯英文释义词被过滤');
      expect(fromBook.fromExamBook, isTrue);
      final fallback = await reader.loadWordsWithSource(limit: 50);
      expect(fallback.words.map((w) => w.id), [202], reason: '回退路径同样过滤空壳');
    });

    test('第三轮 T19：匹配书全空壳→回退全库且 fromExamBook=false（提示如实）', () async {
      final repository = _FakeWordRepository([Word(id: 301, word: 'random_cn', interpret: '随机中文')]);
      repository.bookWords[11] = [Word(id: 101, word: 'en_only', interpret: 'no chinese')];
      final reader = RepositoryQuickReviewWordReader(repository, catalog: _FakeCatalog([cet4Book]));
      expect(await reader.hasExamBooks(ExamType.cet4), isTrue, reason: '目录里确有匹配书');
      final result = await reader.loadWordsWithSource(limit: 50, examType: ExamType.cet4);
      expect(result.fromExamBook, isFalse, reason: '实际词源是全库随机，提示不得假装考试词书');
      expect(result.words.single.id, 301);
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
