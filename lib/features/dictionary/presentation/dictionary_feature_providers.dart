import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/service_locator.dart';
import 'package:word_app/core/repositories/word_repository.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/dictionary/application/dictionary_content_reader.dart';
import 'package:word_app/features/dictionary/application/dictionary_favorite_writer.dart';
import 'package:word_app/features/dictionary/application/dictionary_new_word_writer.dart';
import 'package:word_app/features/dictionary/application/dictionary_search_reader.dart';
import 'package:word_app/features/dictionary/data/service_dictionary_content_reader.dart';
import 'package:word_app/features/dictionary/data/service_dictionary_favorite_writer.dart';
import 'package:word_app/features/dictionary/data/service_dictionary_new_word_writer.dart';
import 'package:word_app/features/dictionary/data/service_dictionary_search_reader.dart';
import 'package:word_app/features/dictionary/presentation/dictionary_detail_state.dart';

/// 装配字典功能域的全部依赖。
///
/// 提供四层所需的所有端口（reader / writer）及聚合状态 [DictionaryDetailState]。
/// 在需要使用字典功能的页面外层包裹此 Scope。
Widget buildDictionaryFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      Provider<DictionaryContentReader>(create: (_) => ServiceDictionaryContentReader()),
      Provider<DictionarySearchReader>(create: (_) => ServiceDictionarySearchReader()),
      Provider<DictionaryFavoriteWriter>(create: (_) => ServiceDictionaryFavoriteWriter()),
      Provider<DictionaryNewWordWriter>(create: (_) => ServiceDictionaryNewWordWriter()),
      // core 仓储转发（深链页经 Provider 通道消费，禁止直取 sl<>——A3 收口）
      Provider<WordRepository>.value(value: sl<WordRepository>()),
    ],
    child: child,
  );
}

/// 创建并注入 [DictionaryDetailState]。
///
/// 将四个端口聚合为单一状态对象，供详情页使用。
Widget buildDictionaryDetailScope({required Word word, required Widget child}) {
  return ChangeNotifierProvider<DictionaryDetailState>(
    create: (context) => DictionaryDetailState(
      searchReader: context.read<DictionarySearchReader>(),
      contentReader: context.read<DictionaryContentReader>(),
      favoriteWriter: context.read<DictionaryFavoriteWriter>(),
      newWordWriter: context.read<DictionaryNewWordWriter>(),
    )..loadWord(word),
    child: child,
  );
}
