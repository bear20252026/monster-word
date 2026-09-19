import 'package:word_app/features/dictionary/domain/dictionary_extra.dart';

/// 字典补充数据读取端口（派生词/近义词/真题例句）。
///
/// presentation 经本端口 + Provider 消费，禁止直连 data 层 DictionaryExtraStore。
abstract interface class DictionaryExtraReader {
  Future<DictionaryExtra?> forWord(String word);
}
