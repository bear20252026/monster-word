import 'package:word_app/models/book.dart';

/// 词书选择操作端口（写）。
///
/// 封装当前选中词书的设置与读取逻辑，写操作经此端口委托给 data 层。
abstract class BookSelectionWriter {
  /// 设置当前选中的词书。
  Future<void> selectBook(int bookId);

  /// 获取当前选中的词书 ID。
  Future<int> getCurrentBookId();

  /// 获取当前选中的词书（便捷方法）。
  Future<Book?> getCurrentBook();
}
