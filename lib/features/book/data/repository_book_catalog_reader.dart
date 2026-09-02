import 'package:word_app/app/service_locator.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/features/book/data/book_repository.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';

/// 基于既有词书仓储的目录读取适配器。
class RepositoryBookCatalogReader implements BookCatalogReader {
  /// 从 service_locator 自动解析依赖。
  factory RepositoryBookCatalogReader.fromServiceLocator() => RepositoryBookCatalogReader._(sl<BookRepository>());

  RepositoryBookCatalogReader._(this._repository);

  /// 显式注入（供测试覆盖）。
  RepositoryBookCatalogReader(this._repository);

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
