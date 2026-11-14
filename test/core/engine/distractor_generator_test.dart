// distractor_generator 表测（测试审计 #3「四选一唯一实现无直接测试」补齐）。
//
// 覆盖：空入参、释义去重、排除当前词、不足 3 个干扰项宁少勿假、池足时 4 选项含正确项。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/engine/distractor_generator.dart';
import 'package:word_app/models/mw_word_process.dart';

MwWordProcess _w(String word, String interpret) => MwWordProcess()
  ..word = word
  ..interpret = interpret;

void main() {
  group('buildRandomFourChoices', () {
    test('当前词为 null 或释义为空：返回空列表（原实现口径）', () {
      expect(buildRandomFourChoices(null, [_w('a', '甲')]), isEmpty);
      expect(buildRandomFourChoices(_w('apple', ''), [_w('a', '甲')]), isEmpty);
    });

    test('恒 4 选项、含正确项、无重复单词', () {
      final pool = [_w('b1', '乙一'), _w('b2', '乙二'), _w('b3', '乙三'), _w('b4', '乙四')];
      final choices = buildRandomFourChoices(_w('apple', '苹果'), pool);
      expect(choices, hasLength(4));
      expect(choices.where((c) => c.word == 'apple'), hasLength(1));
      expect(choices.where((c) => c.interpret == '苹果'), hasLength(1));
      expect(choices.map((c) => c.word).toSet(), hasLength(4), reason: '单词不得重复');
    });

    test('干扰项排除当前词；重复释义只取一次', () {
      final pool = [_w('apple', '苹果'), _w('b1', '乙'), _w('b2', '乙'), _w('b3', '丙')];
      final choices = buildRandomFourChoices(_w('apple', '苹果'), pool);
      expect(choices.where((c) => c.word == 'apple'), hasLength(1), reason: '池内的当前词必须被排除');
      // b1/b2 释义相同：干扰项按释义去重 → 只可能出一个「乙」
      expect(choices.where((c) => c.interpret == '乙'), hasLength(1));
    });

    test('干扰项不足 3 个：宁少勿假，不补占位释义', () {
      // 用户反馈修复（2026-11-14）：旧实现补「释义 N」占位，不是真实释义。
      final choices = buildRandomFourChoices(_w('apple', '苹果'), [_w('b1', '乙')]);
      expect(choices, hasLength(2));
      expect(choices.where((c) => c.word == 'apple'), hasLength(1));
      expect(choices.where((c) => c.word.startsWith('option_')), isEmpty);
    });

    test('空池：仅正确项', () {
      final choices = buildRandomFourChoices(_w('apple', '苹果'), const []);
      expect(choices, hasLength(1));
      expect(choices.single.word, 'apple');
    });
  });
}
