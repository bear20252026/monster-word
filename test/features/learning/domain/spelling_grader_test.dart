// P3-4（架构审计 2026-11-12）：拼写判分纯规则单测。
// 原仅经 widget 测试间接覆盖；此处直接锚定大小写/空白/空串边界。
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/domain/spelling_grader.dart';

void main() {
  group('gradeSpelling', () {
    test('完全一致判对', () {
      expect(gradeSpelling('apple', 'apple'), isTrue);
    });

    test('忽略大小写', () {
      expect(gradeSpelling('Apple', 'apple'), isTrue);
      expect(gradeSpelling('APPLE', 'apple'), isTrue);
      expect(gradeSpelling('aPpLe', 'Apple'), isTrue);
    });

    test('忽略首尾空白', () {
      expect(gradeSpelling('  apple  ', 'apple'), isTrue);
      expect(gradeSpelling('apple', '  apple'), isTrue);
      expect(gradeSpelling('\tapple\n', 'apple'), isTrue);
    });

    test('大小写与空白组合', () {
      expect(gradeSpelling('  Apple  ', 'apple'), isTrue);
    });

    test('拼写错误判错', () {
      expect(gradeSpelling('aple', 'apple'), isFalse);
      expect(gradeSpelling('apples', 'apple'), isFalse);
    });

    test('内部空白不忽略（仅 trim 首尾）', () {
      expect(gradeSpelling('app le', 'apple'), isFalse);
    });

    test('空输入对非空答案判错', () {
      expect(gradeSpelling('', 'apple'), isFalse);
      expect(gradeSpelling('   ', 'apple'), isFalse);
    });

    test('答案为空时仅空输入判对（防御边界）', () {
      expect(gradeSpelling('', ''), isTrue);
      expect(gradeSpelling('  ', ''), isTrue);
      expect(gradeSpelling('apple', ''), isFalse);
    });
  });
}
