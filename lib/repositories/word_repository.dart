// 由 Claude 团队生成 | Monster Word App
// WordRepository — 单词数据访问抽象

import '../../models/word.dart';

/// 单词数据仓库接口
/// 
/// 提供单词（Word）的查询和管理操作抽象。
abstract class WordRepository {
  /// 获取指定词书的所有单词
  Future<List<Word>> getWordsByBookId(int bookId);

  /// 根据 ID 获取单词
  Future<Word?> getWordById(int id);

  /// 根据单词文本获取
  Future<Word?> getWordByText(String text);

  /// 搜索单词
  Future<List<Word>> searchWords(String query, {int? limit});

  /// 获取单词的详细信息（释义、例句等）
  Future<Map<String, dynamic>?> getWordDetails(int wordId);

  /// 获取随机单词（用于干扰项生成）
  Future<List<Word>> getRandomWords(int count, {int? excludeBookId});

  /// 更新单词学习状态
  Future<int> updateWordStatus(int wordId, Map<String, dynamic> status);
}
