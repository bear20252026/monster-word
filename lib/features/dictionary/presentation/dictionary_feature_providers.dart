import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/service_locator.dart';
import 'package:word_app/core/application/word_lookup_reader.dart';
import 'package:word_app/core/application/word_lookup_reader_impl.dart';
import 'package:word_app/core/repositories/word_repository.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/dictionary/application/dictionary_content_reader.dart';
import 'package:word_app/features/dictionary/application/dictionary_extra_reader.dart';
import 'package:word_app/features/dictionary/application/dictionary_favorite_writer.dart';
import 'package:word_app/features/dictionary/application/dictionary_new_word_writer.dart';
import 'package:word_app/features/dictionary/application/dictionary_search_reader.dart';
import 'package:word_app/features/dictionary/data/dictionary_extra.dart';
import 'package:word_app/features/dictionary/data/service_dictionary_favorite_writer.dart';
import 'package:word_app/features/dictionary/presentation/dictionary_detail_state.dart';

/// 装配字典功能域的全部依赖。
///
/// 提供四层所需的所有端口（reader / writer）及聚合状态 [DictionaryDetailState]。
/// 在需要使用字典功能的页面外层包裹此 Scope。
Widget buildDictionaryFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      // 审计 I6：从组合根取端口（构造内已显式注入数据库，presentation 不直连 infrastructure）
      Provider<DictionaryContentReader>(create: (_) => sl<DictionaryContentReader>()),
      Provider<DictionarySearchReader>(create: (_) => sl<DictionarySearchReader>()),
      Provider<DictionaryFavoriteWriter>(create: (_) => ServiceDictionaryFavoriteWriter()),
      Provider<DictionaryNewWordWriter>(create: (_) => sl<DictionaryNewWordWriter>()),
      // 字典补充数据（派生/近义/真题）：presentation 只经端口消费（R3 presentation↛data）
      Provider<DictionaryExtraReader>(create: (_) => const RepositoryDictionaryExtraReader()),
      // N10：查词/偏好端口（R-core-repo / R-prefs）——presentation 不 import core 仓储/SP
      Provider<WordLookupReader>(create: (_) => RepositoryWordLookupReader(sl<WordRepository>())),
      // R2：PresentationPrefs 由外层 learning scope 注入（app.dart 中 learning ⊃ dictionary），
      // 此处禁止再 create 第二实例；独立测试请在自己树上挂 Provider.value。
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
