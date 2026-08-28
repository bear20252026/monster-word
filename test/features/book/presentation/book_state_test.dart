import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/book/application/book_selection_writer.dart';
import 'package:word_app/features/book/application/book_words_reader.dart';
import 'package:word_app/features/book/presentation/book_state.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';

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

/// 模拟 BookWordsReader
class FakeBookWordsReader implements BookWordsReader {
  List<Word> _words = [];

  void setWords(List<Word> words) => _words = words;

  @override
  Future<List<Word>> loadWords(int bookId, {int limit = 50, int offset = 0}) async =>
      _words;
}

void main() {
  group('BookState', () {
    late FakeBookCatalogReader catalogReader;
    late FakeBookSelectionWriter selectionWriter;
    late FakeBookWordsReader wordsReader;
    late BookState state;

    setUp(() {
      catalogReader = FakeBookCatalogReader();
      selectionWriter = FakeBookSelectionWriter();
      wordsReader = FakeBookWordsReader();
      state = BookState(
        catalogReader: catalogReader,
        selectionWriter: selectionWriter,
        wordsReader: wordsReader,
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
      catalogReader.setBooks([
        currentBook,
        Book(id: 2, code: 'cet6', name: 'CET-6', wordCount: 2000),
      ]);
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
      wordsReader.setWords([
        Word(id: 1, word: 'apple'),
        Word(id: 2, word: 'banana'),
      ]);

      await state.loadWords();

      expect(state.words.length, 2);
    });
  });
}
