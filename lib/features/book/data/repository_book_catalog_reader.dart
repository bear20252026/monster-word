import '../../../models/book.dart';
import '../../../repositories/book_repository.dart';
import '../application/book_catalog_reader.dart';

/// 基于既有词书仓储的目录读取适配器。
class RepositoryBookCatalogReader implements BookCatalogReader {
  RepositoryBookCatalogReader({required BookRepository repository}) : _repository = repository;

  final BookRepository _repository;

  @override
  Future<List<Book>> listBooks() => _repository.getBooks();

  @override
  Future<Book?> findById(int bookId) async {
    final books = await _repository.getBooks();
    for (final book in books) {
      if (book.id == bookId) return book;
    }
    return null;
  }
}
