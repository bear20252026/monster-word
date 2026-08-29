import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/di/service_locator.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/features/book/data/book_repository.dart';
import 'package:word_app/features/book/application/book_selection_writer.dart';

/// 基于 SharedPreferences + BookRepository 的词书选择适配器。
///
/// 当前选中词书 ID 通过 SharedPreferences 持久化（与学习进度保持一致），
/// 完整 Book 对象通过 [BookRepository.findById] 获取。
class RepositoryBookSelectionWriter implements BookSelectionWriter {
  RepositoryBookSelectionWriter({this._bookRepository});

  final BookRepository? _bookRepository;

  BookRepository get _bookRepo => _bookRepository ?? sl<BookRepository>();

  static const _currentBookIdKey = 'book_selection_current_book_id';

  @override
  Future<void> selectBook(int bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentBookIdKey, bookId);
  }

  @override
  Future<int> getCurrentBookId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentBookIdKey) ?? 0;
  }

  @override
  Future<Book?> getCurrentBook() async {
    final bookId = await getCurrentBookId();
    if (bookId == 0) return null;
    return _bookRepo.getBookById(bookId);
  }
}
