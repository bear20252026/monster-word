import 'package:word_app/models/word.dart';

/// 跨 feature 共享的「按词文本查词」只读端口。
///
/// presentation 只允许 import 本端口 + Provider 消费；
/// 禁止 import `core/repositories/word_repository.dart`（R-core-repo，2026-09-19）。
abstract interface class WordLookupReader {
  Future<Word?> getWordByText(String text);
}
