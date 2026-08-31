import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/learning/application/learning_progress_reader.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/book/application/book_selection_writer.dart';
import 'package:word_app/features/book/application/book_words_reader.dart';
import 'package:word_app/features/book/data/repository_book_catalog_reader.dart';
import 'package:word_app/features/book/data/repository_book_selection_writer.dart';
import 'package:word_app/features/book/data/repository_book_words_reader.dart';
import 'package:word_app/features/book/presentation/book_state.dart';

/// 装配词书功能域的全部依赖。
///
/// 提供四层所需的所有端口（reader / writer）及聚合状态 [BookState]。
/// 在需要使用词书功能的页面外层包裹此 Scope。
///
/// 内部嵌套 [buildBookStateScope]，确保 [BookState] 在全局可用，
/// 避免 Consumer\<BookState\> 运行时抛出 ProviderNotFoundException。
Widget buildBookFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      Provider<BookCatalogReader>(create: (_) => RepositoryBookCatalogReader.fromServiceLocator()),
      Provider<BookSelectionWriter>(create: (_) => RepositoryBookSelectionWriter()),
      Provider<BookWordsReader>(create: (_) => RepositoryBookWordsReader()),
    ],
    child: buildBookStateScope(child: child),
  );
}

/// 创建并注入 [BookState]。
///
/// 将端口聚合为单一状态对象，供词书相关页面使用。
/// 注意：此 Scope 需要位于 [buildBookFeatureScope] 内部，
/// 以便 [BookState] 能通过 context.read 获取三个端口。
Widget buildBookStateScope({required Widget child}) {
  return ChangeNotifierProvider<BookState>(
    create: (context) => BookState(
      catalogReader: context.read<BookCatalogReader>(),
      selectionWriter: context.read<BookSelectionWriter>(),
      wordsReader: context.read<BookWordsReader>(),
      progressReader: context.read<LearningProgressReader>(),
    )..load(),
    child: child,
  );
}
