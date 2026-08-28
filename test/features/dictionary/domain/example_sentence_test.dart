import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/dictionary/domain/example_sentence.dart';

void main() {
  group('ExampleSentence', () {
    test('hasHighlight 在有高亮片段时为 true', () {
      const ex = ExampleSentence(
        english: 'This is a test.',
        chinese: '这是一个测试。',
        highlight: 'test',
      );
      expect(ex.hasHighlight, isTrue);
    });

    test('hasHighlight 在无高亮时为 false', () {
      const ex = ExampleSentence(
        english: 'Hello world.',
        chinese: '你好世界。',
      );
      expect(ex.hasHighlight, isFalse);
    });

    test('hasHighlight 在高亮为空字符串时为 false', () {
      const ex = ExampleSentence(
        english: 'Hi.',
        chinese: '嗨。',
        highlight: '',
      );
      expect(ex.hasHighlight, isFalse);
    });

    test('fromParsed 正确解析 Map', () {
      final ex = ExampleSentence.fromParsed({
        'english': 'Good morning.',
        'chinese': '早上好。',
        'highlight': 'morning',
      });

      expect(ex.english, 'Good morning.');
      expect(ex.chinese, '早上好。');
      expect(ex.highlight, 'morning');
    });

    test('fromRaw 正确传递所有字段', () {
      final ex = ExampleSentence.fromRaw(
        english: '  Raw english.  ',
        chinese: '  Raw chinese.  ',
        highlight: 'raw',
      );

      expect(ex.english, 'Raw english.');
      expect(ex.chinese, 'Raw chinese.');
      expect(ex.highlight, 'raw');
    });
  });
}
