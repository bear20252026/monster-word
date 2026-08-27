import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/presentation/new_words_state.dart';
import 'package:word_app/models/new_word_record.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/repositories/new_word_repository.dart';

class _MemoryNewWordRepository implements NewWordRepository {
  _MemoryNewWordRepository(Iterable<NewWordRecord> initialRecords)
    : _records = {for (final record in initialRecords) record.wordId: record};

  final Map<int, NewWordRecord> _records;

  @override
  Future<bool> addNewWord(Word word, {String source = 'manual'}) async {
    if (_records.containsKey(word.id)) return false;
    _records[word.id] = NewWordRecord(
      wordId: word.id,
      wordText: word.word,
      source: source,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    return true;
  }

  @override
  Future<List<NewWordRecord>> getNewWords({int? limit, int? offset}) async {
    final records = _records.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  @override
  Future<int> getNewWordCount() async => _records.length;

  @override
  Future<bool> isNewWord(int wordId) async => _records.containsKey(wordId);

  @override
  Future<bool> removeNewWord(int wordId) async => _records.remove(wordId) != null;

  @override
  Future<bool> toggleNewWord(Word word, {String source = 'manual'}) async {
    if (await isNewWord(word.id)) {
      await removeNewWord(word.id);
      return false;
    }
    await addNewWord(word, source: source);
    return true;
  }
}

void main() {
  test('初始化后按仓储记录提供生词数量与状态', () async {
    final state = NewWordsState(
      newWordRepository: _MemoryNewWordRepository([
        const NewWordRecord(wordId: 1, wordText: 'apple', source: 'dictionary', createdAt: 1),
      ]),
    );

    await state.initialize();

    expect(state.initialized, isTrue);
    expect(state.count, 1);
    expect(state.isNewWord(1), isTrue);
  });

  test('切换和移除生词时同步更新展示状态', () async {
    final state = NewWordsState(newWordRepository: _MemoryNewWordRepository(const []));
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
