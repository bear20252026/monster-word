// 词书单词列表页。
//
// 本文件已迁移至 `lib/features/book/presentation/book_words_page.dart`，
// 作为教科书式垂直功能模块的一部分。此处保留为兼容 adapter，
// 将旧构造参数（bookId/bookName）转换为 Book 对象后委托给 feature 页面。

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../features/book/application/book_catalog_reader.dart';
import '../features/book/presentation/book_words_page.dart' as feature;
import '../models/book.dart';

/// 兼容旧路由参数的 adapter 页面。
///
/// 旧路由通过 `bookId` + `bookName` 传参，新 feature 页面需要 `Book` 对象。
/// 此处通过 [BookCatalogReader] 查询完整 Book 后委托给 feature 页面。
class BookWordsPage extends StatelessWidget {
  const BookWordsPage({super.key, required this.bookId, required this.bookName});

  final int bookId;
  final String bookName;

  static const String routeName = '/book-words';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: context.read<BookCatalogReader>().findById(bookId),
      builder: (context, snapshot) {
        final book = snapshot.data ??
            Book(
              id: bookId,
              code: bookName,
              name: bookName,
              wordCount: 0,
            );
        return feature.BookWordsPage(book: book);
      },
    );
  }
}
