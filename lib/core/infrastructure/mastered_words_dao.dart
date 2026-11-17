// P2-10（架构审计 2026-11-12）：掌握词表数据访问层。
//
// SQLite（user_data.db.mastered_words，单词文本主键）为事实来源；内存 Set
// 仅作同步读（isMastered/masteredCount）的索引缓存，不再整表 setStringList 重写。
// FLUTTER_TEST 未注入数据库、或开库失败时，回退旧 SP（mastered_words_v1）
// 行为；SP 键永久保留为回滚快照，迁移幂等（marker + INSERT OR IGNORE）。
// 口径完全对齐 FavoriteWordsDao（收藏先例）。
//
// 第四轮审计 M7（2026-11-17）：与收藏 DAO 约 95% 同构的 init/迁移/写闸/
// 回放/persist 已抽公共基类 WordSetDao（口径逐条随迁），本类只保留掌握
// 语义的窄 API 与差异参数。

import 'package:word_app/core/infrastructure/word_set_dao.dart';

class MasteredWordsDao extends WordSetDao {
  MasteredWordsDao({super.openDatabase})
    : super(
        tableName: 'mastered_words',
        spKey: 'mastered_words_v1',
        migratedMarker: 'mastered_words_sqlite_migrated_v1',
        degradedJournalKey: degradedJournalKey,
        domainLabel: '掌握词表',
      );

  static final MasteredWordsDao instance = MasteredWordsDao._();

  MasteredWordsDao._()
    : super(
        tableName: 'mastered_words',
        spKey: 'mastered_words_v1',
        migratedMarker: 'mastered_words_sqlite_migrated_v1',
        degradedJournalKey: degradedJournalKey,
        domainLabel: '掌握词表',
      );

  /// SQLite 写失败时的掌握意图降级日志（复用收藏/FSRS journal 模式）。
  /// 幂等键即单词文本（mastered_words 主键），回放用 INSERT OR IGNORE / DELETE，
  /// 重复回放无副作用。
  static const String degradedJournalKey = 'mastered_words_degraded_journal_v1';

  // ── 掌握语义窄 API（基类 contains/count 的领域别名） ──

  bool isMastered(String word) => contains(word);

  int get masteredCount => count;
}
