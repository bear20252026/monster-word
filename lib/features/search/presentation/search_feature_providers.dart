import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/app_preferences.dart';
import '../../../repositories/word_repository.dart';
import '../../learning/presentation/learning_favorites_state.dart';
import '../application/example_reader.dart';
import '../application/favorites_accessor.dart';
import '../application/search_history_store.dart';
import '../application/word_search_reader.dart';
import '../data/example_parser_adapter.dart';
import '../data/favorites_accessor_adapter.dart';
import '../data/preferences_search_history_store.dart';
import '../data/repository_word_search_reader.dart';

/// 搜索功能域的依赖装配入口。
///
/// 页面只读取搜索端口；服务定位器和历史偏好对象只在功能域边界被解析。
Widget buildSearchFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      Provider<WordSearchReader>(create: (_) => RepositoryWordSearchReader(repository: sl<WordRepository>())),
      Provider<SearchHistoryStore>(create: (_) => PreferencesSearchHistoryStore(preferences: AppPreferences())),
      Provider<ExampleReader>(create: (_) => const ExampleParserAdapter()),
      ProxyProvider<LearningFavoritesState, FavoritesAccessor>(
        update: (_, favorites, __) => FavoritesAccessorAdapter(favorites),
      ),
    ],
    child: child,
  );
}
