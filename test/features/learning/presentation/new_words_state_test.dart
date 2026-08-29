import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/application/new_words_reader.dart';
import 'package:word_app/features/learning/application/new_words_writer_port.dart';
import 'package:word_app/features/learning/presentation/new_words_state.dart';
import 'package:word_app/models/word.dart';

class _FakeNewWordsReader implements NewWordsReader {
  _FakeNewWordsReader(this.words);

  final List<Word> words;

  @override
  Future<List<Word>> loadWords({int? limit, int? offset}) async => words;
}

class _MemoryNewWordsWriterPort implements NewWordsWriterPort {
  _MemoryNewWordsWriterPort(Iterable<int> initialWordIds) : _wordIds = {...initialWordIds};

  final Set<int> _wordIds;

  @override
  Future<bool> toggleNewWord(Word word, {String source = 'manual'}) async {
    if (_wordIds.contains(word.id)) {
      _wordIds.remove(word.id);
      return false;
    }
    _wordIds.add(word.id);
    return true;
  }

  @override
  Future<bool> removeNewWord(int wordId) async => _wordIds.remove(wordId);
}

void main() {
  test('初始化后按仓储记录提供生词数量与状态', () async {
    final state = NewWordsState(
      newWordsReader: _FakeNewWordsReader([Word(id: 1, word: 'apple')]),
      writerPort: _MemoryNewWordsWriterPort([1]),
    );

    await state.initialize();

    expect(state.initialized, isTrue);
    expect(state.count, 1);
    expect(state.isNewWord(1), isTrue);
  });

  test('切换和移除生词时同步更新展示状态', () async {
    final state = NewWordsState(
      newWordsReader: _FakeNewWordsReader(const []),
      writerPort: _MemoryNewWordsWriterPort(const []),
    );
    await state.initialize();
    final word = Word(id: 2, word: 'banana');

    expect(await state.toggleNewWord(word, source: 'dictionary'), isTrue);
    expect(state.count, 1);
    expect(state.isNewWord(2), isTrue);

    expect(await state.removeNewWord(word), isTrue);
    expect(state.count, 0);
    expect(state.isNewWord(2), isFalse);
  });
}
