// 由 Claude 团队生成 | Monster Word App

// Leitner 引擎行为回归网（审计跟进批次 A）。
// 引擎为 coreengine/LeitnerCardInMemoryImp.java 的 1:1 翻译，本测试锁定：
// 等级分桶、四档评分的升降级规则、分组推进、完成态判定、选项池契约。

import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/engine/core_engine.dart';
import 'package:word_app/core/engine/leitner_engine.dart';
import 'package:word_app/models/mw_word_process.dart';

MwWordProcess _w(String word, {int level = 0}) => MwWordProcess(word: word, interpret: '释义 $word', level: level);

void main() {
  group('init 等级分桶', () {
    test('按 level 0-4 分桶，activeList 优先 level0', () {
      final engine = LeitnerCardEngine();
      engine.init([_w('a'), _w('b', level: 1), _w('c', level: 2), _w('d', level: 3), _w('e', level: 4)]);
      expect(engine.level0.map((w) => w.word), ['a']);
      expect(engine.level1.map((w) => w.word), ['b']);
      expect(engine.level2.map((w) => w.word), ['c']);
      expect(engine.level3.map((w) => w.word), ['d']);
      expect(engine.level4.map((w) => w.word), ['e']);
      expect(engine.currentWord()?.word, 'a'); // 优先出 level0
    });

    test('全部单词保留（打乱不丢词）', () {
      final engine = LeitnerCardEngine();
      final words = List.generate(25, (i) => _w('w$i', level: i % 5));
      engine.init(words);
      expect(engine.totalWords, 25);
    });
  });

  group('四档评分升降级（历史版本 1:1 行为）', () {
    test('iReallyKnow：level+1（上限 4），success++，移出 activeList', () {
      final engine = LeitnerCardEngine();
      final w = _w('word1', level: 2);
      engine.init([w]);
      engine.iReallyKnow();
      expect(w.level, 3);
      expect(w.success, 1);
      expect(w.fail, 0);
      expect(engine.remainWordsNum(), 0);
    });

    test('level=4 时 iReallyKnow 不再升（钳上限）', () {
      final engine = LeitnerCardEngine();
      final w = _w('word1', level: 4);
      engine.init([w]);
      engine.iReallyKnow();
      expect(w.level, 4);
    });

    test('iMayKnow：level-1（下限 0），fail++', () {
      final engine = LeitnerCardEngine();
      final w = _w('word1', level: 2);
      engine.init([w]);
      engine.iMayKnow();
      expect(w.level, 1);
      expect(w.fail, 1);
      final w0 = _w('word2', level: 0);
      engine.init([w0]);
      engine.iMayKnow();
      expect(w0.level, 0);
    });

    test('iDontKnow：level 归 0、state=1、fail++', () {
      final engine = LeitnerCardEngine();
      final w = _w('word1', level: 3);
      engine.init([w]);
      engine.iDontKnow();
      expect(w.level, 0);
      expect(w.state, 1);
      expect(w.fail, 1);
      expect(w.success, 0);
    });

    test('tooEasy：level 直升 4', () {
      final engine = LeitnerCardEngine();
      final w = _w('word1', level: 1);
      engine.init([w]);
      engine.tooEasy();
      expect(w.level, 4);
      expect(w.success, 1);
    });
  });

  group('分组推进', () {
    test('组内推进：未到组尾时 index 前进，不出新组', () {
      final engine = LeitnerCardEngine(strategy: const LearnStrategy(groupSize: 3));
      final words = List.generate(6, (i) => _w('w$i'));
      engine.init(words);
      expect(engine.currentWord()?.word, isNotNull);
      engine.iReallyKnow();
      expect(engine.unFinishedNum(), 2); // 3 - 1
      expect(engine.remainWordsNum(), 5);
    });

    test('学完全部词：完成态由 getDataPreparedState 判定（lessonIsOver 引擎怪癖锁定）', () {
      final engine = LeitnerCardEngine(strategy: const LearnStrategy(groupSize: 3));
      final words = List.generate(6, (i) => _w('w$i'));
      engine.init(words);
      for (var i = 0; i < 6; i++) {
        expect(engine.lessonIsOver(), isFalse);
        engine.iReallyKnow();
      }
      // 已知怪癖（历史版本 1:1 行为）：最后一组学完后 _buildNextGroup 因 activeList
      // 已空而跳过，_currentGroup 保留旧组 → lessonIsOver() 恒 false。
      // 该方法在 App 层零消费，完成判定实际走 getDataPreparedState，故不改引擎、锁实际行为。
      expect(engine.lessonIsOver(), isFalse, reason: '引擎怪癖：currentGroup 保留最后一组');
      expect(engine.remainWordsNum(), 0);
      expect(engine.finishedNum(), 6);
      expect(engine.getDataPreparedState(), DataPreparedState.finished);
    });

    test('tooEasy 提前结束当前组', () {
      final engine = LeitnerCardEngine(strategy: const LearnStrategy(groupSize: 3));
      engine.init(List.generate(6, (i) => _w('w$i')));
      engine.tooEasy();
      // tooEasy 直接跳到下一组：剩余 activeList 是 3 个（第二组），当前组已换
      expect(engine.unFinishedNum(), 3);
    });
  });

  group('选项池契约', () {
    test('始终 4 个选项且含正确项', () {
      final engine = LeitnerCardEngine(strategy: const LearnStrategy(groupSize: 4));
      engine.init(List.generate(4, (i) => _w('w$i')));
      final current = engine.currentWord()!;
      final choices = engine.getListChoicesRandom();
      expect(choices.length, 4);
      expect(choices.any((p) => p.word == current.word), isTrue);
      // 选项无重复单词
      expect(choices.map((p) => p.word).toSet().length, 4);
    });

    test('空引擎无选项、currentWord 为 null', () {
      final engine = LeitnerCardEngine();
      engine.init([]);
      expect(engine.currentWord(), isNull);
      expect(engine.getListChoicesRandom(), isEmpty);
      expect(engine.getDataPreparedState(), DataPreparedState.none);
    });
  });
}
