// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 核心学习引擎：翻译自 coreengine/BBCoreEngine.java（v3.2 源码 1:1）
// 抽象引擎：定义学习/复习流程的核心方法 + 4选1干扰项生成

import 'dart:math';

import '../models/bb_word_process.dart';
import '../models/lexis_dict.dart';

/// 数据准备状态（原版常量）
enum DataPreparedState {
  finished(0), // DATA_PREPARED_FINISHED
  part(1), // DATA_PREPARED_PART
  none(2); // DATA_PREPARED_NONE

  const DataPreparedState(this.value);
  final int value;
}

/// 选项对（单词, 释义）——原版 Pair&lt;String,String&gt;
class WordChoicePair {
  final String word;
  final String interpret;
  const WordChoicePair(this.word, this.interpret);
}

/// 核心学习引擎抽象类（翻译自 BBCoreEngine.java）
abstract class BBCoreEngine {
  /// 学习/复习标签（原版 UMEventLabel：learn/review）
  String eventLabel;

  /// 当前单词进度
  BBWordProcess? currentWordProcess;

  BBCoreEngine({this.eventLabel = 'learn'});

  /// 当前单词
  BBWordProcess? currentWord();

  /// 已完成数量
  int finishedNum();

  /// 数据准备状态
  DataPreparedState getDataPreparedState();

  /// 上一组数据
  List<BBWordProcess>? getLastGroupData() => null;

  /// 4 选 1 随机选项（原版 getListChoicesRandom）
  List<WordChoicePair> getListChoicesRandom();

  /// 单词最大等级
  int getWordMaxLevel();

  /// 不认识（原版 iDontKnow）
  void iDontKnow();

  /// 模糊（原版 iMayKnow）
  void iMayKnow();

  /// 认识（原版 iReallyKnow）
  void iReallyKnow();

  /// 是否全部太简单
  bool isAllTooEasy();

  /// 本节课是否结束
  bool lessonIsOver();

  /// 下一组
  void nextGroup();

  /// 下一个单词
  BBWordProcess? nextWord();

  /// 剩余单词数
  int remainWordsNum();

  /// 太简单
  void tooEasy();

  /// 未完成数
  int unFinishedNum();

  /// 更新随机选项
  void updateListChoicesRandom();

  /// 获取释义第一行（原版 getFirstIterpret）
  String _getFirstInterpret(String? str) {
    if (str == null) return '';
    final trimmed = str.trim();
    if (trimmed.isEmpty) return '';
    final idx = trimmed.indexOf('\n');
    return idx > 0 ? trimmed.substring(0, idx) : trimmed;
  }

  /// 4 选 1 干扰项生成（原版 confuseItemsForChoice，逻辑 1:1）
  /// 优先用当前词的形近词，否则从词库随机取 3 个不同释义
  List<Interpret> confuseItemsForChoice(BBWordProcess? wordProcess) {
    // 分支 1：当前词有形近词（>=3 个）→ 用形近词
    final confusedList = wordProcess?.confusedList ?? [];
    if (wordProcess != null && confusedList.length >= 3) {
      final result = <Interpret>[];
      final size = confusedList.length;
      final start = randomWithRange(0, size - 1);
      for (var i = 0; i < 3; i++) {
        result.add(confusedList[(start + i) % size]);
      }
      return result;
    }

    // 分支 2：从随机选项池取 3 个不同释义
    final choices = getListChoicesRandom();
    final result = <Interpret>[];
    final usedWords = <String>{};
    final usedInterprets = <String>{};
    final currentWordText = currentWordProcess?.word ?? '';
    final currentFirstInterpret =
        _getFirstInterpret(currentWordProcess?.interpret ?? '');

    var guard = 0;
    while (result.length < 3 && guard < 100 && choices.isNotEmpty) {
      guard++;
      final pair = choices[randomWithRange(0, choices.length - 1)];
      final word = pair.word;
      final interpret = pair.interpret;
      final firstInterpret = _getFirstInterpret(interpret);
      if (interpret.isEmpty ||
          word == currentWordText ||
          usedWords.contains(word) ||
          currentFirstInterpret == firstInterpret ||
          usedInterprets.contains(interpret)) {
        continue;
      }
      usedWords.add(word);
      usedInterprets.add(interpret);
      result.add(Interpret.fromJson({'p': '', 'i': interpret}));
    }
    return result;
  }

  /// 随机范围（原版 Tools.randomWithRange，含两端）
  int randomWithRange(int min, int max) {
    if (max <= min) return min;
    return min + Random().nextInt(max - min + 1);
  }

  /// 打乱列表（原版 Collections.shuffle 语义）
  List<T> shuffleList<T>(List<T> list) {
    final copy = List<T>.from(list);
    copy.shuffle(Random());
    return copy;
  }
}
