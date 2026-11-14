import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/utils/query_normalize.dart';

void main() {
  group('normalizeQuery（2026-11-14）', () {
    test('全角字母/数字→半角并折小写', () {
      expect(normalizeQuery('ａｐｐｌｅ'), 'apple');
      expect(normalizeQuery('１００'), '100');
      expect(normalizeQuery('Ａｐｐｌｅ'), 'apple');
    });

    test('大写折小写 + trim', () {
      expect(normalizeQuery('  Apple  '), 'apple');
    });

    test('全角空格→半角空格并被 trim', () {
      expect(normalizeQuery('　apple　'), 'apple');
    });

    test('中文不受影响', () {
      expect(normalizeQuery('苹果'), '苹果');
      expect(normalizeQuery(' 苹果 '), '苹果');
    });

    test('空串归一后仍空', () {
      expect(normalizeQuery(''), '');
      expect(normalizeQuery('   '), '');
    });
  });
}
