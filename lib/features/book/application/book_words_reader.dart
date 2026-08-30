import 'package:word_app/models/word.dart';

/// 词书单词列表端口（读）。
///
/// 封装指定词书的单词列表查询逻辑。
abstract class BookWordsReader {
  /// 加载指定词书的【全部】单词（按字母 A-Z 排序）。
  ///
  /// 词书列表页标注的词数必须与返回的列表长度一致（验收标准）。
  /// [bookId] 词书 ID
  Future<List<Word>> loadWords(int bookId);
}
