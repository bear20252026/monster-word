import 'package:word_app/models/book.dart';

/// 词书入口流程所需的词书目录读取能力。
abstract interface class BookCatalogReader {
  Future<List<Book>> listBooks();

  Future<Book?> findById(int bookId);
}
