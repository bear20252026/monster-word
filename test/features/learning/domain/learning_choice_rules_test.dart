import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/domain/choice_generator.dart';
import 'package:word_app/features/learning/domain/definition_formatter.dart';

void main() {
  group('DefinitionFormatter', () {
    test('extractChinese 读取 def.cn', () {
      const interpret = '[{"def":[{"cn":"有效的","en":"valid"}]}]';

      expect(DefinitionFormatter.extractChinese(interpret), '有效的');
    });

    test('extractChinese 回退至 def.cndef', () {
      const interpret = '[{"def":[{"cndef":"备用释义"}]}]';

      expect(DefinitionFormatter.extractChinese(interpret), '备用释义');
    });

    test('extractChinese 对空值与非法 JSON 返回空字符串', () {
      expect(DefinitionFormatter.extractChinese(''), isEmpty);
      expect(DefinitionFormatter.extractChinese('not-json'), isEmpty);
      expect(DefinitionFormatter.extractChinese('[{"def":[]}]'), isEmpty);
    });
  });

  group('ChoiceGenerator', () {
    const correct = ChoiceCandidate(word: 'valid', interpret: '[{"def":[{"cn":"有效的"}]}]');

    test('生成一个正确选项和三个唯一释义的候选项', () {
      final choices = ChoiceGenerator.generate(
        correct: correct,
        candidates: const [
          ChoiceCandidate(word: 'legal', interpret: '[{"def":[{"cn":"合法的"}]}]'),
          ChoiceCandidate(word: 'sound', interpret: '[{"def":[{"cn":"健全的"}]}]'),
          ChoiceCandidate(word: 'plain', interpret: '[{"def":[{"cn":"明显的"}]}]'),
          ChoiceCandidate(word: 'repeat', interpret: '[{"def":[{"cn":"合法的"}]}]'),
          ChoiceCandidate(word: 'empty', interpret: ''),
        ],
        random: Random(7),
      );

      expect(choices, hasLength(4));
      expect(choices.where((choice) => choice.word == correct.word), hasLength(1));
      expect(choices.map((choice) => choice.interpret).toSet(), hasLength(4));
      expect(choices.map((choice) => choice.word), isNot(contains('repeat')));
      expect(choices.map((choice) => choice.word), isNot(contains('empty')));
    });

    test('优先选择包含中文释义的干扰项', () {
      const noChinese = ChoiceCandidate(word: 'raw', interpret: '[{"def":[{"en":"raw"}]}]');
      const chineseOne = ChoiceCandidate(word: 'first', interpret: '[{"def":[{"cn":"第一"}]}]');
      const chineseTwo = ChoiceCandidate(word: 'second', interpret: '[{"def":[{"cn":"第二"}]}]');
      const chineseThree = ChoiceCandidate(word: 'third', interpret: '[{"def":[{"cn":"第三"}]}]');

      final choices = ChoiceGenerator.generate(
        correct: correct,
        candidates: const [noChinese, chineseOne, chineseTwo, chineseThree],
        random: Random(11),
      );

      final distractorWords = choices.where((choice) => choice.word != correct.word).map((choice) => choice.word);
      expect(distractorWords, containsAll(<String>['first', 'second', 'third']));
      expect(distractorWords, isNot(contains('raw')));
    });

    test('候选池不足时用稳定的兜底释义补齐四个选项', () {
      final choices = ChoiceGenerator.generate(correct: correct, candidates: const [], random: Random(3));

      expect(choices, hasLength(4));
      expect(choices.map((choice) => choice.interpret), containsAll(<String>['非标准用法', '罕用释义', '非正式表达']));
    });
  });
}
