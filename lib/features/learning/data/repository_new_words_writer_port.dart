import '../../../core/di/service_locator.dart';
import '../../../models/word.dart';
import 'package:word_app/core/repositories/new_word_repository.dart';
import '../application/new_words_writer_port.dart';

/// Adapts [NewWordRepository] (legacy repositories) to [NewWordsWriterPort] (application layer).
class RepositoryNewWordsWriterPort implements NewWordsWriterPort {
  final NewWordRepository _repository;

  RepositoryNewWordsWriterPort(this._repository);

  factory RepositoryNewWordsWriterPort.fromServiceLocator() =>
      RepositoryNewWordsWriterPort(sl<NewWordRepository>());

  @override
  Future<bool> toggleNewWord(Word word, {String source = 'manual'}) {
    return _repository.toggleNewWord(word, source: source);
  }

  @override
  Future<bool> removeNewWord(int wordId) {
    return _repository.removeNewWord(wordId);
  }
}
