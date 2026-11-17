// MEM/U6：单词收藏数据访问层。
//
// SQLite（user_data.db.favorite_words，单词文本主键）为事实来源；内存 Set
// 仅作同步读（isFavorite/favoriteCount）的索引缓存，不再整表 jsonEncode 重写。
// FLUTTER_TEST 未注入数据库、或开库失败时，回退旧 SP（favorite_words_v1）
// 行为；SP 键永久保留为回滚快照，迁移幂等（marker + INSERT OR IGNORE）。
//
// 第四轮审计 M7（2026-11-17）：与 mastered_words_dao 约 95% 同构的
// init/迁移/写闸/回放/persist 已抽公共基类 WordSetDao（口径逐条随迁），
// 本类只保留收藏语义的窄 API 与差异参数。

import 'package:word_app/core/infrastructure/word_set_dao.dart';

class FavoriteWordsDao extends WordSetDao {
  FavoriteWordsDao({super.openDatabase})
    : super(
        tableName: 'favorite_words',
        spKey: 'favorite_words_v1',
        migratedMarker: 'favorite_words_sqlite_migrated_v1',
        degradedJournalKey: degradedJournalKey,
        domainLabel: '单词收藏',
      );

  static final FavoriteWordsDao instance = FavoriteWordsDao._();

  FavoriteWordsDao._()
    : super(
        tableName: 'favorite_words',
        spKey: 'favorite_words_v1',
        migratedMarker: 'favorite_words_sqlite_migrated_v1',
        degradedJournalKey: degradedJournalKey,
        domainLabel: '单词收藏',
      );

  /// P1-01 余项：SQLite 写失败时的收藏意图降级日志（复用 FSRS journal 模式）。
  /// 幂等键即单词文本（favorite_words 主键），回放用 INSERT OR IGNORE / DELETE，
  /// 重复回放无副作用。
  static const String degradedJournalKey = 'favorite_words_degraded_journal_v1';

  // ── 收藏语义窄 API（基类 contains/count 的领域别名） ──

  bool isFavorite(String word) => contains(word);

  int get favoriteCount => count;
}
