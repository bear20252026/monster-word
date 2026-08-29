// Adapter — 从路由参数（bookId/bookName）解析为 Book 对象，委托给 feature 的 BookWordsPage
// 保留此文件作为路由兼容层，核心实现已在 features/book/presentation/book_words_page.dart
import 'package:flutter/material.dart';

import '../features/book/presentation/book_words_page.dart' as feature;
import '../models/book.dart';

/// 路由兼容适配器：将 Map 参数（bookId + bookName）转为 Book 对象并委托给 feature BookWordsPage
class BookWordsPage extends StatelessWidget {
  const BookWordsPage({super.key, required this.bookId, required this.bookName});

  final int bookId;
  final String bookName;

  static const routeName = feature.BookWordsPage.routeName;

  @override
  Widget build(BuildContext context) {
    // 构造一个最小 Book 对象用于路由兼容；真实 BookWordsPage 通过 BookState 读取完整数据
    final book = Book(id: bookId, name: bookName, wordCount: 0, code: '');
    return feature.BookWordsPage(book: book);
  }
}
