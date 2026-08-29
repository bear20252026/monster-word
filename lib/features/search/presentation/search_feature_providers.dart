import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/learning/learning_favorites_store.dart';
import 'package:word_app/features/search/application/example_reader.dart';
import 'package:word_app/features/search/application/favorites_accessor.dart';
import 'package:word_app/features/search/application/search_history_store.dart';
import 'package:word_app/features/search/application/word_search_reader.dart';
import 'package:word_app/features/search/data/example_parser_adapter.dart';
import 'package:word_app/features/search/data/favorites_accessor_adapter.dart';
import 'package:word_app/features/search/data/preferences_search_history_store.dart';
import 'package:word_app/features/search/data/repository_word_search_reader.dart';

/// 搜索功能域的依赖装配入口。
///
/// 页面只读取搜索端口；服务定位器和历史偏好对象只在功能域边界被解析。
Widget buildSearchFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      Provider<WordSearchReader>(
        create: (_) => RepositoryWordSearchReader.fromServiceLocator(),
      ),
      Provider<SearchHistoryStore>(
        create: (_) => PreferencesSearchHistoryStore.fromServiceLocator(),
      ),
      Provider<ExampleReader>(create: (_) => const ExampleParserAdapter()),
      ProxyProvider<LearningFavoritesStore, FavoritesAccessor>(
        update: (_, favorites, _) => FavoritesAccessorAdapter(favorites),
      ),
    ],
    child: child,
  );
}
