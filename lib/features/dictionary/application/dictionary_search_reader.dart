import '../../../models/word.dart';

/// 词典搜索端口（读）。
///
/// 封装单词搜索逻辑，按前缀、模糊或智能模式返回匹配的词表。
abstract class DictionarySearchReader {
  /// 按前缀搜索单词。
  Future<List<Word>> searchByPrefix(String prefix);

  /// 模糊搜索单词。
  Future<List<Word>> searchFuzzy(String query);

  /// 智能搜索：先前缀，不足再补模糊。
  Future<List<Word>> searchSmart(String query);
}
