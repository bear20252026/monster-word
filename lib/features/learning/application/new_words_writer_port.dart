import '../../../models/word.dart';

/// Port: new-words mutations (toggle / remove).
/// Presentation states depend on this abstraction, not on
/// `lib/repositories/new_word_repository.dart` directly.
abstract class NewWordsWriterPort {
  Future<bool> toggleNewWord(Word word, {String source = 'manual'});

  Future<bool> removeNewWord(int wordId);
}
