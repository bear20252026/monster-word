import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/book/data/repository_book_catalog_reader.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/features/book/data/book_repository.dart';

void main() {
  test('reads the book catalog and resolves books by id', () async {
    final books = [
      Book(id: 1, code: 'CET4', name: '四级词书', wordCount: 4500),
      Book(id: 2, code: 'CET6', name: '六级词书', wordCount: 5500),
    ];
    final repository = _FakeBookRepository(books);
    final reader = RepositoryBookCatalogReader(repository);

    expect(await reader.listBooks(), same(books));
    expect(await reader.findById(2), same(books[1]));
    expect(await reader.findById(99), isNull);
    expect(repository.getBooksCalls, 3);
  });
}

class _FakeBookRepository implements BookRepository {
  _FakeBookRepository(this.books);

  final List<Book> books;
  int getBooksCalls = 0;

  @override
  Future<List<Book>> getBooks() async {
    getBooksCalls++;
    return books;
  }

  @override
  Future<Book?> getBookById(int id) => throw UnimplementedError();

  @override
  Future<int> getWordCount(int bookId) => throw UnimplementedError();

  @override
  Future<List<Book>> searchBooks(String query) => throw UnimplementedError();

  @override
  Future<int> insertBook(Book book) => throw UnimplementedError();

  @override
  Future<int> updateBook(Book book) => throw UnimplementedError();

  @override
  Future<int> deleteBook(int id) => throw UnimplementedError();
}
