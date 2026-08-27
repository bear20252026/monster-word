import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/presentation/learning_queue_state.dart';
import 'package:word_app/models/word.dart';

void main() {
  group('LearningQueueSnapshot', () {
    test('复制并冻结输入词条列表', () {
      final source = [Word(word: 'first')];
      final snapshot = LearningQueueSnapshot(currentBook: null, words: source, currentIndex: 0, learnedCount: 0);

      source.add(Word(word: 'later'));

      expect(snapshot.words.map((word) => word.word), ['first']);
      expect(() => snapshot.words.add(Word(word: 'unexpected')), throwsUnsupportedError);
    });
  });
}
