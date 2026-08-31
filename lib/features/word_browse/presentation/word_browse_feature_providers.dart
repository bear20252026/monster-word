import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/word_browse/application/sentence_favorites_store.dart';
import 'package:word_app/features/word_browse/application/word_notes_store.dart';
import 'package:word_app/features/word_browse/data/repository_sentence_favorites_store.dart';
import 'package:word_app/features/word_browse/data/repository_word_notes_store.dart';

/// 词条浏览功能域的依赖装配入口。
///
/// 词条详情页等展示页面只读取 application 端口；历史仓储只在此组合根被解析。
Widget buildWordBrowseFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      Provider<WordNotesStore>(create: (_) => RepositoryWordNotesStore.fromServiceLocator()),
      Provider<SentenceFavoritesStore>(create: (_) => RepositorySentenceFavoritesStore.fromServiceLocator()),
    ],
    child: child,
  );
}
