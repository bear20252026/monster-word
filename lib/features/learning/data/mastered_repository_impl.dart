import 'package:word_app/core/infrastructure/mastered_words_dao.dart';
import 'package:word_app/features/learning/data/mastered_repository.dart';

/// 已掌握单词标记仓储。
///
/// P2-10（架构审计 2026-11-12）：事实来源从 SP StringList 全量覆写迁到 SQLite
/// （mastered_words 表，单词文本主键），对齐收藏/笔记口径。本类退化为 MasteredWordsDao
/// 的薄适配层——接口不变，消费方零改动；DAO 内部保留 SP 回退（测试未注入/开库失败）
/// 与首启幂等迁移，存量 mastered_words_v1 数据无损。
class MasteredRepositoryImpl implements MasteredRepository {
  MasteredRepositoryImpl({MasteredWordsDao? dao}) : _dao = dao ?? MasteredWordsDao.instance;

  final MasteredWordsDao _dao;

  @override
  Future<Set<String>> getMasteredWords() async {
    await _dao.ensureLoaded();
    return _dao.getWords();
  }

  @override
  bool isMastered(String word) => _dao.isMastered(word);

  @override
  int get masteredCount => _dao.masteredCount;

  @override
  Future<void> toggleMastered(String word) async {
    await _dao.toggle(word);
  }
}
