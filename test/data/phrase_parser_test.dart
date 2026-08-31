// 由 Claude 团队生成 | Monster Word App
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/parsers/phrase_parser.dart';

void main() {
  group('PhraseParser.parse', () {
    test('空串/非法输入返回空，不抛异常', () {
      expect(PhraseParser.parse(''), isEmpty);
      expect(PhraseParser.parse('{}'), isEmpty);
      expect(PhraseParser.parse('not json'), isEmpty);
      expect(PhraseParser.parse('123'), isEmpty);
      expect(PhraseParser.parse('null'), isEmpty);
    });

    test('标准词组结构解析出 en/cn + 分组', () {
      const raw = '[{"t":2,"p":[{"en":"abandon a child","cn":"GLOSS","exams":"[]"}],"pseqs":{"ZK":[1,2]}}]';
      final groups = PhraseParser.parse(raw);
      expect(groups, hasLength(1));
      final g = groups.first;
      expect(g.type, 2);
      expect(g.items, hasLength(1));
      final item = g.items.first;
      expect(item.en, 'abandon a child');
      expect(item.cn, 'GLOSS');
      expect(item.exams, isEmpty);
    });

    test('多组多短语按类型分组', () {
      const raw =
          '[{"t":1,"p":[{"en":"look up","cn":"check"},{"en":"look after","cn":"take care"}]},'
          '{"t":3,"p":[{"en":"look forward to","cn":"expect"}]}]';
      final groups = PhraseParser.parse(raw);
      expect(groups, hasLength(2));
      expect(groups[0].items, hasLength(2));
      expect(groups[1].items, hasLength(1));
      expect(groups[0].items[0].en, 'look up');
      expect(groups[1].items[0].cn, 'expect');
    });

    test('exams 支持 JSON 数组串/逗号串', () {
      const raw = '[{"t":1,"p":[{"en":"give up","cn":"quit","exams":"[\\"gaokao\\",\\"cet4\\"]"}]}]';
      expect(PhraseParser.parse(raw).first.items.first.exams, ['gaokao', 'cet4']);
      const raw2 = '[{"t":1,"p":[{"en":"give up","cn":"quit","exams":"gaokao,cet4"}]}]';
      expect(PhraseParser.parse(raw2).first.items.first.exams, ['gaokao', 'cet4']);
    });

    test('跳过缺 en 的无效条目，只保留有效短语', () {
      const raw = '[{"t":1,"p":[{"cn":"only zh"},{"en":"valid one","cn":"v"}]}]';
      final items = PhraseParser.parse(raw).first.items;
      expect(items, hasLength(1));
      expect(items.first.en, 'valid one');
    });
  });

  group('PhraseParser.flatItems / hasData', () {
    test('flatItems 拉平所有分组', () {
      const raw = '[{"t":1,"p":[{"en":"a","cn":"A"}]},{"t":2,"p":[{"en":"b","cn":"B"},{"en":"c","cn":"C"}]}]';
      final all = PhraseParser.flatItems(raw);
      expect(all, hasLength(3));
      expect(all.map((e) => e.en), ['a', 'b', 'c']);
    });

    test('hasData 对空/无 effective 短语为 false', () {
      expect(PhraseParser.hasData(''), isFalse);
      expect(PhraseParser.hasData('[{"t":1,"p":[]}]'), isFalse);
      expect(PhraseParser.hasData('[{"t":1,"p":[{"cn":"x"}]}]'), isFalse);
      expect(PhraseParser.hasData('[{"t":1,"p":[{"en":"go on","cn":"continue"}]}]'), isTrue);
    });
  });
}
