// ─────────────────────────────────────────────────────────────────
// 共享仓储契约层（2026-08-31 架构审计 A2 结论：保留于此，不迁入单域）
//
// 词库/用户主数据被 learning/dictionary/search/word_browse/quick_review/
// checkin/account 共 7 个域消费——这是跨域共享数据的业务本质。
// 迁入任何单一 feature 都会迫使其他域反向依赖该域的 data 层（违反分层）。
// 约定：
// 1. 本目录只放「被 ≥2 个域消费」的仓储契约 + 实现；单域私有的
//    仓储应放在该 feature 的 data/ 下。
// 2. 新增仓储需评审：优先考虑端口-适配器（接口进对应域 application/）。
// ─────────────────────────────────────────────────────────────────
// 由 Claude 团队生成 | Monster Word App
// WordRepository — 单词数据访问抽象

import 'package:word_app/models/word.dart';

/// 单词数据仓库接口
///
/// 提供单词（Word）的查询和管理操作抽象。
abstract class WordRepository {
  /// 获取指定词书的所有单词
  ///
  /// [limit] 不传或传 null = 全量加载（SQLite LIMIT -1）；
  /// 传具体值才截断。禁止在端口消费方硬编码截断值（REG-LEARN-001）。
  Future<List<Word>> getWordsByBookId(int bookId, {int? limit, int? offset});

  /// 根据 ID 获取单词
  Future<Word?> getWordById(int id);

  /// 根据单词文本获取
  Future<Word?> getWordByText(String text);

  /// 根据单词文本批量获取
  Future<List<Word>> getWordsByTexts(Iterable<String> texts);

  /// 根据单词 ID 批量获取
  Future<List<Word>> getWordsByIds(Iterable<int> ids);

  /// 搜索单词
  Future<List<Word>> searchWords(String query, {int? limit});

  /// 获取单词的详细信息（释义、例句等）
  Future<Map<String, dynamic>?> getWordDetails(int wordId);

  /// 获取随机单词（用于干扰项生成）
  Future<List<Word>> getRandomWords(int count, {int? excludeBookId});

  /// 更新单词学习状态
  Future<int> updateWordStatus(int wordId, Map<String, dynamic> status);
}
