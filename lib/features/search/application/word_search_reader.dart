import '../../../models/word.dart';

/// 搜索流程所需的单词查询能力。
abstract interface class WordSearchReader {
  Future<List<Word>> search(String query, {int? limit});
}
