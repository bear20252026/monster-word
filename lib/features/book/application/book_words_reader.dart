import 'package:word_app/models/word.dart';

/// 词书单词列表端口（读）。
///
/// 封装指定词书的单词列表查询逻辑。
abstract class BookWordsReader {
  /// 加载指定词书的单词列表。
  ///
  /// [bookId] 词书 ID
  /// [limit] 返回数量上限（默认 50）
  /// [offset] 分页偏移（默认 0）
  Future<List<Word>> loadWords(int bookId, {int limit = 50, int offset = 0});
}
