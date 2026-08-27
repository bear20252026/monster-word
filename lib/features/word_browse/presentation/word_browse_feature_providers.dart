import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/di/service_locator.dart';
import '../../../repositories/fav_repository.dart';
import '../../../repositories/note_repository.dart';
import '../application/sentence_favorites_store.dart';
import '../application/word_notes_store.dart';
import '../data/repository_sentence_favorites_store.dart';
import '../data/repository_word_notes_store.dart';

/// 词条浏览功能域的依赖装配入口。
///
/// 词条详情页等展示页面只读取 application 端口；历史仓储只在此组合根被解析。
Widget buildWordBrowseFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      Provider<WordNotesStore>(create: (_) => RepositoryWordNotesStore(repository: sl<NoteRepository>())),
      Provider<SentenceFavoritesStore>(
        create: (_) => RepositorySentenceFavoritesStore(repository: sl<FavRepository>()),
      ),
    ],
    child: child,
  );
}
