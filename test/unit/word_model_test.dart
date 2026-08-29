// 单元测试：Word 模型 + WordChoicePair 释义解析
// 复现 bug：API 返回 def 为 ID 引用时，释义显示原始 JSON 符号

import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/engine/core_engine.dart';
import 'package:word_app/models/word.dart';

void main() {
  group('Word.cleanInterpret', () {
    test('当 def 为 ID 引用 [22285] 时，不应显示原始 JSON 符号', () {
      // ✅ 复现 bug：API 返回的 interpret 字段包含整数 ID 引用
      final word = Word(id: 1, word: 'amuse', interpret: '[{"t":"vt.","def":[22285]}]');

      final result = word.cleanInterpret;

      // ❌ 修复前：显示 '[{"t":"vt.","def":[22285]}]' 或空字符串
      // ✅ 修复后：应提取可读文本，不包含 JSON 符号
      expect(result.contains('['), isFalse, reason: '不应包含左方括号');
      expect(result.contains(']'), isFalse, reason: '不应包含右方括号');
      expect(result.contains('{'), isFalse, reason: '不应包含左花括号');
      expect(result.contains('}'), isFalse, reason: '不应包含右花括号');
      expect(result.contains('"def"'), isFalse, reason: '不应包含 JSON 键名');
    });

    test('当 def 为 ID 引用时，应提取词性文本', () {
      final word = Word(id: 1, word: 'amuse', interpret: '[{"t":"vt.","def":[22285]}]');

      final result = word.cleanInterpret;

      // 至少应提取词性 "vt."
      expect(result, contains('vt.'));
    });

    test('当 def 为完整对象时，应提取中英文释义', () {
      final word = Word(
        id: 2,
        word: 'hello',
        interpret: '[{"t":"int.","def":[{"en":"used as a greeting","cn":"你好；打招呼"}]}]',
      );

      final result = word.cleanInterpret;

      expect(result, contains('你好'));
      expect(result, contains('int.'));
    });

    test('当 interpret 为纯文本时，应原样返回', () {
      final word = Word(id: 3, word: 'test', interpret: 'n. 测试；考试');

      final result = word.cleanInterpret;

      expect(result, contains('测试'));
      expect(result, contains('考试'));
    });

    test('当 interpret 为空时，应返回空字符串', () {
      final word = Word(id: 4, word: 'empty');

      expect(word.cleanInterpret, isEmpty);
    });
  });

  group('Word.formattedDefinitions', () {
    test('当 def 为 ID 引用时，应回退到 cleanInterpret 而非空字符串', () {
      final word = Word(id: 1, word: 'amuse', interpret: '[{"t":"vt.","def":[22285]}]');

      final result = word.formattedDefinitions;

      // ❌ 修复前：返回空字符串（parsedDefinitions 为空）
      // ✅ 修复后：回退到 cleanInterpret，至少包含词性
      expect(result, isNotEmpty);
      expect(result, contains('vt.'));
    });

    test('当 def 为完整对象时，应返回格式化释义', () {
      final word = Word(
        id: 2,
        word: 'hello',
        interpret: '[{"t":"int.","def":[{"en":"used as a greeting","cn":"你好"}]}]',
      );

      final result = word.formattedDefinitions;

      expect(result, contains('int.'));
      expect(result, contains('你好'));
    });
  });

  group('Word.parsedDefinitions', () {
    test('当 def 为 ID 引用时，应返回空列表（跳过非 Map 项）', () {
      final word = Word(id: 1, word: 'amuse', interpret: '[{"t":"vt.","def":[22285]}]');

      final result = word.parsedDefinitions;

      // ID 引用是整数，不是 Map，应被跳过
      expect(result, isEmpty);
    });

    test('当 def 为完整对象时，应正确解析', () {
      final word = Word(
        id: 2,
        word: 'hello',
        interpret: '[{"t":"int.","def":[{"en":"used as a greeting","cn":"你好"}]}]',
      );

      final result = word.parsedDefinitions;

      expect(result, hasLength(1));
      expect(result.first.partOfSpeech, 'int.');
      expect(result.first.cnDef, '你好');
      expect(result.first.enDef, 'used as a greeting');
    });
  });

  // ============================================================
  // WordChoicePair 测试 — 这是学习页面选项实际使用的数据模型
  // ============================================================
  group('WordChoicePair.cleanInterpret', () {
    test('当 def 为 ID 引用 [22285] 时，不应显示原始 JSON 符号', () {
      // ✅ 关键修复：WordChoicePair 是学习页面选项的实际数据模型
      // 之前其 cleanInterpret 只清理 HTML，不处理 JSON，导致显示原始 JSON 符号
      final pair = WordChoicePair('amuse', '[{"t":"vt.","def":[22285]}]');

      final result = pair.cleanInterpret;

      expect(result.contains('['), isFalse, reason: '不应包含左方括号');
      expect(result.contains(']'), isFalse, reason: '不应包含右方括号');
      expect(result.contains('{'), isFalse, reason: '不应包含左花括号');
      expect(result.contains('}'), isFalse, reason: '不应包含右花括号');
    });

    test('当 def 为 ID 引用时，应提取词性文本', () {
      final pair = WordChoicePair('amuse', '[{"t":"vt.","def":[22285]}]');

      final result = pair.cleanInterpret;

      expect(result, contains('vt.'));
    });

    test('当 def 为完整对象时，应提取中英文释义', () {
      final pair = WordChoicePair('hello', '[{"t":"int.","def":[{"en":"used as a greeting","cn":"你好"}]}]');

      final result = pair.cleanInterpret;

      expect(result, contains('你好'));
      expect(result, contains('int.'));
    });

    test('当 interpret 为纯文本时，应原样返回', () {
      final pair = WordChoicePair('test', 'n. 测试；考试');

      final result = pair.cleanInterpret;

      expect(result, contains('测试'));
    });

    test('当 interpret 为空时，应返回空字符串', () {
      final pair = WordChoicePair('empty', '');

      expect(pair.cleanInterpret, isEmpty);
    });
  });

  group('WordChoicePair.parsedDefinitions', () {
    test('当 def 为 ID 引用时，应返回空列表', () {
      final pair = WordChoicePair('amuse', '[{"t":"vt.","def":[22285]}]');

      expect(pair.parsedDefinitions, isEmpty);
      expect(pair.hasStructuredDefinitions, isFalse);
    });

    test('当 def 为完整对象时，应正确解析', () {
      final pair = WordChoicePair('hello', '[{"t":"int.","def":[{"en":"used as a greeting","cn":"你好"}]}]');

      final defs = pair.parsedDefinitions;

      expect(defs, hasLength(1));
      expect(defs.first['pos'], 'int.');
      expect(defs.first['cn'], '你好');
      expect(defs.first['en'], 'used as a greeting');
    });
  });
}
