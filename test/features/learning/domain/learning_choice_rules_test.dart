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

    test('候选池不足时宁少勿假：不再补硬编码占位释义', () {
      // 用户反馈修复（2026-11-14）：旧实现补「非标准用法/罕用释义/非正式表达」，
      // 假释义且文案固定，在不同单词题目里反复出现。现在只返回真实选项。
      final choices = ChoiceGenerator.generate(correct: correct, candidates: const [], random: Random(3));

      expect(choices, hasLength(1));
      expect(choices.single.word, correct.word);
      expect(choices.map((choice) => choice.interpret), isNot(contains('非标准用法')));
    });

    test('候选池只有两个真实干扰项时返回三选项而非补占位', () {
      final choices = ChoiceGenerator.generate(
        correct: correct,
        candidates: const [
          ChoiceCandidate(word: 'legal', interpret: '[{"def":[{"cn":"合法的"}]}]'),
          ChoiceCandidate(word: 'sound', interpret: '[{"def":[{"cn":"健全的"}]}]'),
        ],
        random: Random(3),
      );

      expect(choices, hasLength(3));
      expect(choices.map((choice) => choice.interpret).toSet(), hasLength(3));
    });
  });
}
