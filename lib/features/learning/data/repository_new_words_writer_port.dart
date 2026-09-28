import 'package:word_app/models/word.dart';
import 'package:word_app/core/repositories/new_word_repository.dart';
import 'package:word_app/features/learning/application/new_words_writer_port.dart';
import 'package:word_app/core/repositories/new_word_id_cache.dart';

/// Adapts [NewWordRepository] (legacy repositories) to [NewWordsWriterPort] (application layer).
class RepositoryNewWordsWriterPort implements NewWordsWriterPort {
  final NewWordRepository _repository;

  RepositoryNewWordsWriterPort(this._repository);

  @override
  Future<bool> toggleNewWord(Word word, {String source = 'manual'}) async {
    final result = await _repository.toggleNewWord(word, source: source);
    // 审计 I34：写后维护共享缓存，词典域同步 isNewWord 即时一致
    NewWordIdCache.instance.mark(word.id, added: result);
    return result;
  }

  @override
  Future<bool> removeNewWord(int wordId) async {
    final result = await _repository.removeNewWord(wordId);
    if (result) NewWordIdCache.instance.mark(wordId, added: false);
    return result;
  }
}
