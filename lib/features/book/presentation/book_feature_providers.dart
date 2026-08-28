import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/di/service_locator.dart';
import '../../../repositories/book_repository.dart';
import '../application/book_catalog_reader.dart';
import '../data/repository_book_catalog_reader.dart';

/// 词书功能域的依赖装配入口。
///
/// 词书页面只读取 [BookCatalogReader]，不直接感知服务定位器或仓储实现。
Widget buildBookFeatureScope({required Widget child}) {
  return Provider<BookCatalogReader>(
    create: (_) => RepositoryBookCatalogReader(repository: sl<BookRepository>()),
    child: child,
  );
}
