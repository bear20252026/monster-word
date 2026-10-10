import 'package:word_app/models/word.dart';

/// Port: new-words mutations (toggle / remove).
/// Presentation states depend on this abstraction, not on
/// `lib/core/repositories/` 下的实现 directly（历史路径 lib/repositories/ 已不存在，2026-10 审计修注）
abstract class NewWordsWriterPort {
  Future<bool> toggleNewWord(Word word, {String source = 'manual'});

  Future<bool> removeNewWord(int wordId);
}
