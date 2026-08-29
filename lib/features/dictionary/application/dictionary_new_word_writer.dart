import 'package:word_app/models/word.dart';

/// 生词本操作端口（写）。
///
/// 封装生词添加/移除逻辑，写操作经此端口委托给 data 层。
abstract class DictionaryNewWordWriter {
  /// 切换单词生词状态，返回切换后是否为生词。
  Future<bool> toggleNewWord(Word word, {String source});

  /// 判断单词是否已在生词本中。
  bool isNewWord(int wordId);
}
