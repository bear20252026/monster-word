import 'package:word_app/models/word.dart';

/// 词书单词列表的只读应用端口。
abstract interface class BookWordsReader {
  Future<List<Word>> loadWords(int bookId);
}
