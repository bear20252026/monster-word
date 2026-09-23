import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/book/application/book_selection_writer.dart';
import 'package:word_app/features/book/application/book_word_list_reader.dart';
import 'package:word_app/features/book/presentation/book_state.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';

import '../test_helpers/fake_learning_progress_reader.dart';

/// 模拟 BookCatalogReader
class FakeBookCatalogReader implements BookCatalogReader {
  List<Book> _books = [];
  Book? _bookById;

  void setBooks(List<Book> books) => _books = books;
  void setBookById(Book? book) => _bookById = book;

  @override
  Future<List<Book>> listBooks() async => _books;

  @override
  Future<Book?> findById(int bookId) async => _bookById;
}

/// 模拟 BookSelectionWriter
class FakeBookSelectionWriter implements BookSelectionWriter {
  int _currentBookId = 0;
  Book? _currentBook;

  void setCurrentBookId(int id) => _currentBookId = id;
  void setCurrentBook(Book? book) => _currentBook = book;

  @override
  Future<void> selectBook(int bookId) async => _currentBookId = bookId;

  @override
  Future<int> getCurrentBookId() async => _currentBookId;

  @override
  Future<Book?> getCurrentBook() async => _currentBook;
}

/// 模拟 BookWordListReader（MEM/F2：分页语义可观测）
class FakeBookWordListReader implements BookWordListReader {
  List<Word> _words = [];
  int loadWordPageCalls = 0;

  void setWords(List<Word> words) => _words = words;

  @override
  Future<List<Word>> loadWords(int bookId, {int limit = 50, int offset = 0}) async => _words;

  @override
  Future<int> countWords(int bookId) async => _words.length;

  @override
  Future<List<Word>> loadWordPage(int bookId, {required int offset, required int limit}) async {
    loadWordPageCalls++;
    return _words.skip(offset).take(limit).toList();
  }

  @override
  Future<List<String>> loadWordTexts(int bookId) async => [for (final word in _words) word.word];
}

void main() {
  group('BookState', () {
    late FakeBookCatalogReader catalogReader;
    late FakeBookSelectionWriter selectionWriter;
    late FakeBookWordListReader wordsReader;
    late BookState state;

    setUp(() {
      catalogReader = FakeBookCatalogReader();
      selectionWriter = FakeBookSelectionWriter();
      wordsReader = FakeBookWordListReader();
      state = BookState(
        catalogReader: catalogReader,
        selectionWriter: selectionWriter,
        wordsReader: wordsReader,
        progressReader: FakeLearningProgressReader(learnedCount: 42),
      );
    });

    test('初始状态正确', () {
      expect(state.books, isEmpty);
      expect(state.currentBook, isNull);
      expect(state.words, isEmpty);
      expect(state.loading, isFalse);
    });

    test('load 加载词书列表和当前词书', () async {
      final currentBook = Book(id: 1, code: 'cet4', name: 'CET-4', wordCount: 4000);
      catalogReader.setBooks([currentBook, Book(id: 2, code: 'cet6', name: 'CET-6', wordCount: 2000)]);
      catalogReader.setBookById(currentBook);
      selectionWriter.setCurrentBookId(1);
      selectionWriter.setCurrentBook(currentBook);

      await state.load();

      expect(state.loading, isFalse);
      expect(state.books.length, 2);
      expect(state.currentBook, isNotNull);
      expect(state.currentBook!.id, 1);
    });

    test('selectAndLoad 选择词书并加载', () async {
      final book = Book(id: 2, code: 'cet6', name: 'CET-6', wordCount: 2000);
      await state.selectAndLoad(book);

      expect(selectionWriter.getCurrentBookId(), completion(2));
    });

    test('loadWords 加载单词列表', () async {
      // 先设置当前词书 ID，否则 loadWords 会提前返回
      selectionWriter.setCurrentBookId(1);
      await state.load(); // 加载当前词书
      wordsReader.setWords([Word(id: 1, word: 'apple'), Word(id: 2, word: 'banana')]);

      await state.loadWords();

      expect(state.words.length, 2);
    });

    test('loadWords 从 progressReader 获取已学数', () async {
      selectionWriter.setCurrentBookId(1);
      await state.load();
      wordsReader.setWords([Word(id: 1, word: 'apple'), Word(id: 2, word: 'banana'), Word(id: 3, word: 'cherry')]);

      await state.loadWords();

      // FakeLearningProgressReader 预设 learnedCount = 42
      expect(state.statistics!.learnedWords, 42);
      expect(state.statistics!.totalWords, 3);
      expect(state.statistics!.unlearnWords, 0); // 超过总量时 clamp 为 0
    });

    // XP-FIX-4: loadWords 失败时设置 _error 给用户反馈
    test('loadWords 失败时设置 error 反馈', () async {
      selectionWriter.setCurrentBookId(1);
      await state.load();
      // 模拟 wordsReader 抛异常
      wordsReader.setWords([]);
      final errorReader = _ErrorBookWordListReader();
      final errorState = BookState(
        catalogReader: catalogReader,
        selectionWriter: selectionWriter,
        wordsReader: errorReader,
        progressReader: FakeLearningProgressReader(learnedCount: 0),
      );
      // 先设置当前词书
      await errorState.selectAndLoad(Book(id: 1, code: 'cet4', name: 'CET-4', wordCount: 100));

      await errorState.loadWords();

      expect(errorState.error, isNotNull);
      expect(errorState.words, isEmpty);
    });

    // XP-FIX-4: totalWords 优先使用词书自身的 wordCount
    test('totalWords 优先使用词书 wordCount 而非 words.length', () async {
      final bookWithCount = Book(id: 1, code: 'cet4', name: 'CET-4', wordCount: 500);
      catalogReader.setBooks([bookWithCount]);
      catalogReader.setBookById(bookWithCount);
      selectionWriter.setCurrentBookId(1);
      selectionWriter.setCurrentBook(bookWithCount);
      await state.load();

      wordsReader.setWords([Word(id: 1, word: 'apple'), Word(id: 2, word: 'banana')]);

      await state.loadWords();

      // totalWords 应该使用词书的 wordCount（500），而非 words.length（2）
      expect(state.statistics!.totalWords, 500);
    });

    // XP-FIX-4: 兜底 — 词书不在列表中时清除无效 ID
    test('load 时当前词书不在列表中则清除无效 ID', () async {
      catalogReader.setBooks([Book(id: 2, code: 'cet6', name: 'CET-6', wordCount: 2000)]);
      catalogReader.setBookById(null);
      selectionWriter.setCurrentBookId(999); // 无效 ID

      await state.load();

      expect(state.currentBook, isNull);
    });

    // MEM/F2: 列表浏览走分页窗口，整书不一次性进内存
    test('loadWords 只加载首页窗口，totalWords 取 COUNT 口径', () async {
      final book = Book(id: 1, code: 'big', name: '大词书', wordCount: 250);
      catalogReader.setBooks([book]);
      catalogReader.setBookById(book);
      selectionWriter.setCurrentBookId(1);
      selectionWriter.setCurrentBook(book);
      wordsReader.setWords([for (var i = 0; i < 250; i++) Word(id: i, word: 'w${i.toString().padLeft(3, '0')}')]);

      await state.selectAndLoad(book);

      expect(state.words.length, BookState.pageSize, reason: '首屏只加载一个窗口');
      expect(state.totalWords, 250, reason: '总量为 COUNT 口径而非窗口长度');
      expect(state.hasMore, isTrue);
      expect(state.statistics!.totalWords, 250);
    });

    // MEM/F2: loadMore 续页到底后收敛，重复触发为 no-op
    test('loadMore 追加剩余页并收敛 hasMore，再触发不请求', () async {
      final book = Book(id: 1, code: 'big', name: '大词书', wordCount: 250);
      catalogReader.setBooks([book]);
      catalogReader.setBookById(book);
      selectionWriter.setCurrentBookId(1);
      selectionWriter.setCurrentBook(book);
      wordsReader.setWords([for (var i = 0; i < 250; i++) Word(id: i, word: 'w${i.toString().padLeft(3, '0')}')]);

      await state.selectAndLoad(book);
      expect(state.words.length, BookState.pageSize);

      await state.loadMore();

      expect(state.words.length, 250);
      expect(state.hasMore, isFalse, reason: '尾页不足一窗即到底');

      final callsAfterExhausted = wordsReader.loadWordPageCalls;
      await state.loadMore();
      expect(wordsReader.loadWordPageCalls, callsAfterExhausted, reason: '到底后 loadMore 必须为 no-op');
    });
  });
}

/// 模拟会抛异常的 BookWordListReader
class _ErrorBookWordListReader implements BookWordListReader {
  @override
  Future<List<Word>> loadWords(int bookId, {int limit = 50, int offset = 0}) async {
    throw Exception('模拟数据库异常');
  }

  @override
  Future<int> countWords(int bookId) async {
    throw Exception('模拟数据库异常');
  }

  @override
  Future<List<Word>> loadWordPage(int bookId, {required int offset, required int limit}) async {
    throw Exception('模拟数据库异常');
  }

  @override
  Future<List<String>> loadWordTexts(int bookId) async {
    throw Exception('模拟数据库异常');
  }
}
