import '../../../models/word.dart';

/// 词典内容页所需的只读查询端口。
abstract interface class DictionaryContentReader {
  Future<List<Word>> getDerivedWords(String word);

  Future<List<Word>> getSynonyms(String word);

  Future<List<Map<String, String>>> getExamExamples(String word);
}
