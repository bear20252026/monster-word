import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/parsers/example_parser.dart';
import 'package:word_app/core/parsers/phrase_parser.dart';

/// 模拟词库 phrase 原始 JSON 格式
const _rawPhrase =
    '[{"t":2,"p":[{"en":"say hello","cn":"打招呼","exams":"[\\"四级\\"]"},{"en":"hello world","cn":"你好世界","exams":"[]"}]}]';

/// 模拟词库 example 原始 JSON 格式
const _rawExample = '{"v":1,"data":[{"g":[{"s":[{"e":"He <b>said</b> hello to me.","c":"他跟我打招呼。","b":"课本"}]}]}]}';

void main() {
  group('PhraseParser.readableText', () {
    test('含短语时输出可读文本无花括号', () {
      final phrases = PhraseParser.flatItems(_rawPhrase);
      expect(phrases.length, 2);
      final text = phrases.map((p) => '${p.en}　${p.cn}').join('; ');
      expect(text, isNot(contains('{')));
      expect(text, contains('say hello'));
      expect(text, contains('打招呼'));
      // exams 标签在 PhraseItem 中正确解析
      expect(phrases.first.exams, contains('四级'));
    });

    test('空短语返回空列表', () {
      final phrases = PhraseParser.flatItems('');
      expect(phrases, isEmpty);
    });
  });

  group('ExampleParser.readableText', () {
    test('含例句时输出 cleanEn 和中文，无 HTML 标签', () {
      final examples = ExampleParser.parse(_rawExample);
      expect(examples, isNotEmpty);
      final ex = examples.first;
      expect(ex.cleanEn, isNot(contains('<b>')));
      expect(ex.cleanEn, contains('said hello'));
      expect(ex.cn, contains('打招呼'));
      expect(ex.source, '课本');
    });

    test('空例句返回空列表', () {
      final examples = ExampleParser.parse('');
      expect(examples, isEmpty);
    });
  });

  group('导出文本格式验证', () {
    test('TXT 格式不含原始 JSON 花括号', () {
      final buffer = StringBuffer();
      buffer.write('hello  həˈloʊ  int. 你好；n. 问候');
      if (PhraseParser.hasData(_rawPhrase)) {
        buffer.write('\n  短语:');
        for (final p in PhraseParser.flatItems(_rawPhrase)) {
          buffer.write('\n    ${p.en}　${p.cn}');
          if (p.exams.isNotEmpty) buffer.write(' [${p.exams.join(', ')}]');
        }
      }
      final examples = ExampleParser.parse(_rawExample);
      if (examples.isNotEmpty) {
        buffer.write('\n  例句:');
        for (final ex in examples) {
          buffer.write('\n    ${ex.cleanEn}');
          if (ex.cn.isNotEmpty) buffer.write(' — ${ex.cn}');
          if (ex.source.isNotEmpty) buffer.write(' (${ex.source})');
        }
      }
      final text = buffer.toString();
      expect(text, isNot(contains('{')));
      expect(text, isNot(contains('"e"')));
      expect(text, isNot(contains('"c"')));
      expect(text, contains('hello'));
      expect(text, contains('打招呼'));
      expect(text, contains('said hello'));
      expect(text, contains(' — '));
    });

    test('无数据时优雅降级不输出空段', () {
      final buffer = StringBuffer();
      buffer.write('hello  int. 问候');
      final phrases = PhraseParser.flatItems('');
      final examples = ExampleParser.parse('');
      // 空数据时不添加短语/例句段
      expect(phrases, isEmpty);
      expect(examples, isEmpty);
      expect(buffer.toString(), isNot(contains('短语:')));
      expect(buffer.toString(), isNot(contains('例句:')));
    });
  });
}
