import 'dart:math';

import 'package:word_app/features/learning/domain/definition_formatter.dart';

/// 供学习与复习流程共享的最小候选词值对象。
class ChoiceCandidate {
  const ChoiceCandidate({required this.word, required this.interpret});

  final String word;
  final String interpret;
}

/// 生成四选一候选项的纯领域规则。
class ChoiceGenerator {
  const ChoiceGenerator._();

  /// 返回一个正确选项与至多三个干扰项。
  ///
  /// 用户反馈修复（2026-11-14）：候选不足时**不再**用「非标准用法/罕用释义/
  /// 非正式表达」等硬编码占位补齐——占位不是真实释义，且文案固定，导致不同
  /// 单词的题目里反复出现同一批假选项。现在宁少勿假：返回 1~4 个选项
  /// （正确项 + 至多 3 个真实干扰项）。真实干扰项的扩充由会话状态从词库
  /// 随机取样完成（见 LearningSessionState / ReviewSessionState 的候选池）。
  static List<ChoiceCandidate> generate({
    required ChoiceCandidate correct,
    required Iterable<ChoiceCandidate> candidates,
    Random? random,
  }) {
    final effectiveRandom = random ?? Random();
    final seenInterprets = <String>{correct.interpret};
    final withChinese = <ChoiceCandidate>[];
    final withoutChinese = <ChoiceCandidate>[];

    for (final candidate in candidates) {
      if (candidate.word == correct.word || candidate.interpret.isEmpty || !seenInterprets.add(candidate.interpret)) {
        continue;
      }

      if (DefinitionFormatter.extractChinese(candidate.interpret).isEmpty) {
        withoutChinese.add(candidate);
      } else {
        withChinese.add(candidate);
      }
    }

    withChinese.shuffle(effectiveRandom);
    withoutChinese.shuffle(effectiveRandom);

    final distractors = <ChoiceCandidate>[...withChinese.take(3)];
    if (distractors.length < 3) {
      distractors.addAll(withoutChinese.take(3 - distractors.length));
    }

    final choices = <ChoiceCandidate>[correct, ...distractors];
    choices.shuffle(effectiveRandom);
    return choices;
  }
}
