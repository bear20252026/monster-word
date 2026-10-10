import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/app/service_locator.dart';
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
    // 写返回值校验：失败时下次启动回旧词书，静默不可接受。
    if (!await prefs.setInt(_currentBookIdKey, bookId)) {
      reportSwallowedError('词书选择写入失败', StateError('setInt($bookId) returned false'), StackTrace.current);
    }
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
