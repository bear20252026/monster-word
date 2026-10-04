// 由 Claude 团队生成 | Monster Word App

// 4 选 1 干扰项单一真相（审计提升点 I3）：Leitner 引擎与超级记忆引擎此前
// 各持一份逐字相同的 updateListChoicesRandom（~35 行），兜底文案还各自
// 硬编码。本文件是唯一的构建实现，两个引擎只传各自的数据源。
import 'package:word_app/core/engine/core_engine.dart';
import 'package:word_app/models/mw_word_process.dart';

/// 构建 4 选 1 随机选项：1 个正确项 + 3 个干扰项，整体乱序。
///
/// [current] 为当前词（词或释义为空返回空列表——与原实现口径一致）；
/// [pool] 为干扰项候选池（两引擎分别传当前组+已完成组 / 复习列表+已复习）。
/// 干扰项按释义去重、排除当前词；不足 3 个时用占位释义补齐。
List<WordChoicePair> buildRandomFourChoices(MwWordProcess? current, Iterable<MwWordProcess> pool) {
  if (current == null || current.interpret.isEmpty) return [];

  // 正确选项
  final correctPair = WordChoicePair(current.word, current.interpret);

  // 构建干扰项池（排除当前单词，按单词去重，按释义去重——头注释契约；
  // 原实现只按单词去重，同义干扰项可重复出现造成两个「都对」的选项）。
  // 释义集合以当前词释义为种子：与正确项同义的干扰项同样排除。
  final seen = <String>{current.word};
  final seenInterpret = <String>{current.interpret};
  final distractorPool = <WordChoicePair>[];
  for (final w in pool) {
    if (w.interpret.isNotEmpty && !seen.contains(w.word) && seenInterpret.add(w.interpret)) {
      seen.add(w.word);
      distractorPool.add(WordChoicePair(w.word, w.interpret));
    }
  }

  // 随机选取 3 个干扰项
  distractorPool.shuffle();
  final distractors = distractorPool.take(3).toList();

  // 如果干扰项不足3个，用通用释义填充
  while (distractors.length < 3) {
    distractors.add(WordChoicePair('option_${distractors.length}', '释义 ${distractors.length + 1}'));
  }

  // 组合4个选项并随机打乱顺序
  final allChoices = [correctPair, ...distractors];
  allChoices.shuffle();
  return allChoices;
}
