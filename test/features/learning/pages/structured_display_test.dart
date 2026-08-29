import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/parsers/example_parser.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/widgets/word_root_tab.dart';

void main() {
  group('ExampleParser 结构化解析', () {
    test('解析单词例句 JSON 数组', () {
      // 词库格式: {"v":1,"data":[{"g":[{"s":[{"e":"...","c":"...","b":"..."}]}]}]}
      final input =
          '{"v":1,"data":[{"g":[{"s":[{"e":"This is a test sentence.","c":"这是一个测试句子。","b":"oxford"}]}]}]}';
      final result = ExampleParser.parse(input);

      expect(result.length, 1);
      expect(result[0].en, 'This is a test sentence.');
      expect(result[0].cn, '这是一个测试句子。');
      expect(result[0].source, 'oxford');
    });

    test('解析多条例句', () {
      final input =
          '{"v":1,"data":[{"g":[{"s":[{"e":"Hello world.","c":"你好世界。"},{"e":"Good morning.","c":"早上好。"}]}]}]}';
      final result = ExampleParser.parse(input);

      expect(result.length, 2);
      expect(result[0].en, 'Hello world.');
      expect(result[1].cn, '早上好。');
    });

    test('空数组返回空列表', () {
      expect(ExampleParser.parse('[]'), isEmpty);
    });

    test('非法 JSON 返回空列表', () {
      expect(ExampleParser.parse('not json'), isEmpty);
    });

    test('空字符串返回空列表', () {
      expect(ExampleParser.parse(''), isEmpty);
    });
  });

  group('WordRootTab 结构化显示', () {
    testWidgets('渲染词根信息', (tester) async {
      const json =
          '[{"root":"act","meaning":"to do","words":["action","active"]}]';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WordRootTab(wordRootJson: json),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(WordRootTab), findsOneWidget);
    });

    testWidgets('空字符串不崩溃', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WordRootTab(wordRootJson: ''),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(WordRootTab), findsOneWidget);
    });
  });

  group('Word 模型例句/词根字段', () {
    test('含 example + wordRoot 的 Word 构造正确', () {
      final word = Word(
        word: 'test',
        example:
            '{"v":1,"data":[{"g":[{"s":[{"e":"This is a test.","c":"这是一个测试。","b":"oxford"}]}]}]}',
        wordRoot: '[{"root":"test","meaning":"to try","words":["testing"]}]',
      );

      expect(word.example, isNotEmpty);
      expect(word.wordRoot, isNotEmpty);

      final sentences = ExampleParser.parse(word.example);
      expect(sentences.length, 1);
      expect(sentences[0].en, 'This is a test.');
      expect(sentences[0].cn, '这是一个测试。');
    });

    test('空 example + wordRoot 优雅降级', () {
      final word = Word(word: 'test', example: '', wordRoot: '');

      expect(word.example, isEmpty);
      expect(ExampleParser.parse(word.example), isEmpty);
    });
  });
}
