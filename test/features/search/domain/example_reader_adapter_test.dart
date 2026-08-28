import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/search/data/example_parser_adapter.dart';

void main() {
  group('ExampleParserAdapter', () {
    const adapter = ExampleParserAdapter();

    test('parse 空字符串返回空列表', () {
      final result = adapter.parse('');
      expect(result, isEmpty);
    });

    test('parse 有效 JSON 返回 SearchExample 列表', () {
      // 词库 example 字段格式：{"v":1,"data":[{"g":[{"s":[{"e":"...", "c":"...", "b":"..."}]}]}]}
      final input = '''
{
  "v": 1,
  "data": [
    {
      "oid": 1,
      "g": [
        {
          "s": [
            {
              "e": "I am a <b>student</b>",
              "c": "我是学生",
              "b": "课本"
            }
          ]
        }
      ]
    }
  ]
}
''';
      final result = adapter.parse(input);
      expect(result.length, 1);
      expect(result[0].en, 'I am a <b>student</b>');
      expect(result[0].cn, '我是学生');
      expect(result[0].source, '课本');
    });

    test('parse 兼容旧 ExampleParser 识别例句', () {
      final input = '''
{
  "v": 1,
  "data": [
    {
      "g": [
        {
          "s": [
            {"e": "He <b>is</b> a teacher.", "c": "他是一名老师。"}
          ]
        }
      ]
    }
  ]
}
''';
      final result = adapter.parse(input);
      expect(result.length, 1);
      expect(result[0].cleanEn, 'He is a teacher.');
    });
  });
}
