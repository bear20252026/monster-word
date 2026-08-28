import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/repositories/mastered_repository.dart';

import 'package:word_app/features/learning/data/learning_progress_reader_impl.dart';

/// Fake MasteredRepository for testing
class _FakeMasteredRepository implements MasteredRepository {
  _FakeMasteredRepository(this._masteredWords);

  final Set<String> _masteredWords;

  @override
  Future<Set<String>> getMasteredWords() async => _masteredWords;

  @override
  bool isMastered(String word) => _masteredWords.contains(word);

  @override
  Future<void> toggleMastered(String word) async {
    if (_masteredWords.contains(word)) {
      _masteredWords.remove(word);
    } else {
      _masteredWords.add(word);
    }
  }

  @override
  int get masteredCount => _masteredWords.length;
}

void main() {
  group('LearningProgressReaderImpl', () {
    late _FakeMasteredRepository fakeMastered;
    late LearningProgressReaderImpl reader;

    setUp(() {
      fakeMastered = _FakeMasteredRepository({'apple', 'banana', 'cherry', 'dog', 'elephant'});
      reader = LearningProgressReaderImpl(masteredRepository: fakeMastered);
    });

    test('countLearnedWords 对交集计数正确', () async {
      final wordTexts = ['apple', 'banana', 'cat', 'dog', 'fish'];
      final count = await reader.countLearnedWords(wordTexts);

      // apple, banana, dog 共 3 个在 mastered 词集中
      expect(count, 3);
    });

    test('空词集返回 0', () async {
      final count = await reader.countLearnedWords([]);
      expect(count, 0);
    });

    test('全部已掌握时返回词集总数', () async {
      final wordTexts = ['apple', 'banana', 'cherry'];
      final count = await reader.countLearnedWords(wordTexts);
      expect(count, 3);
    });

    test('无交集时返回 0', () async {
      final wordTexts = ['fox', 'grape', 'hat'];
      final count = await reader.countLearnedWords(wordTexts);
      expect(count, 0);
    });

    test('空 mastered 词集时返回 0', () async {
      final emptyMastered = _FakeMasteredRepository({});
      final readerWithEmpty = LearningProgressReaderImpl(masteredRepository: emptyMastered);

      final count = await readerWithEmpty.countLearnedWords(['apple', 'banana']);
      expect(count, 0);
    });
  });
}
