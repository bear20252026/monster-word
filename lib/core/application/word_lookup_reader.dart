import 'package:word_app/models/word.dart';

/// 跨 feature 共享的「按词文本查词 / 随机取样」只读端口。
///
/// presentation 只允许 import 本端口 + Provider 消费；
/// 禁止 import `core/repositories/word_repository.dart`（R-core-repo，2026-09-19）。
abstract interface class WordLookupReader {
  Future<Word?> getWordByText(String text);

  /// 随机取样真实词（用户反馈修复 2026-11-14：四选一干扰项候选池扩充，
  /// 避免小队列/余池收缩时重复老面孔或补假占位）。
  Future<List<Word>> getRandomWords(int count);
}
