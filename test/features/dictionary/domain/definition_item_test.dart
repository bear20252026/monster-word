import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/dictionary/domain/definition_item.dart';
import 'package:word_app/models/definition.dart';

void main() {
  group('DefinitionItem', () {
    test('formatted 用分号连接释义', () {
      const item = DefinitionItem(
        partOfSpeech: 'n.',
        definitions: ['帮助', '援助'],
      );
      expect(item.formatted, '帮助; 援助');
    });

    test('hasDefinitions 在释义非空时为 true', () {
      const item = DefinitionItem(partOfSpeech: 'v.', definitions: ['做']);
      expect(item.hasDefinitions, isTrue);
    });

    test('hasDefinitions 在释义为空时为 false', () {
      const item = DefinitionItem(partOfSpeech: 'v.', definitions: []);
      expect(item.hasDefinitions, isFalse);
    });

    group('fromParsed', () {
      test('按词性分组并聚合中文释义', () {
        const parsed = [
          Definition(partOfSpeech: 'n.', enDef: '', cnDef: '帮助'),
          Definition(partOfSpeech: 'n.', enDef: '', cnDef: '援助'),
          Definition(partOfSpeech: 'v.', enDef: '', cnDef: '帮助'),
        ];

        final items = DefinitionItem.fromParsed(parsed);

        expect(items, hasLength(2));
        expect(items[0].partOfSpeech, 'n.');
        expect(items[0].definitions, ['帮助', '援助']);
        expect(items[1].partOfSpeech, 'v.');
        expect(items[1].definitions, ['帮助']);
      });

      test('中文释义为空时回退到英文释义', () {
        const parsed = [
          Definition(partOfSpeech: 'n.', enDef: 'help', cnDef: ''),
        ];

        final items = DefinitionItem.fromParsed(parsed);
        expect(items[0].definitions, ['help']);
      });

      test('跳过中英文释义均为空的 Definition', () {
        const parsed = [
          Definition(partOfSpeech: 'n.', enDef: 'valid', cnDef: ''),
          Definition(partOfSpeech: '', enDef: '', cnDef: ''),
        ];

        final items = DefinitionItem.fromParsed(parsed);
        expect(items, hasLength(1));
        expect(items[0].partOfSpeech, 'n.');
      });

      test('空输入返回空列表', () {
        expect(DefinitionItem.fromParsed(null), isEmpty);
        expect(DefinitionItem.fromParsed([]), isEmpty);
      });
    });
  });
}
