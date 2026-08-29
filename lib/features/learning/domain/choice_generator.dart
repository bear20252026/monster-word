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

  static const List<ChoiceCandidate> _fallbacks = [
    ChoiceCandidate(word: '', interpret: '非标准用法'),
    ChoiceCandidate(word: '', interpret: '罕用释义'),
    ChoiceCandidate(word: '', interpret: '非正式表达'),
  ];

  /// 返回一个正确选项与至多三个干扰项；候选池不足时使用稳定的兜底释义补齐。
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

    for (final fallback in _fallbacks) {
      if (distractors.length >= 3 || !seenInterprets.add(fallback.interpret)) {
        continue;
      }
      distractors.add(fallback);
    }

    final choices = <ChoiceCandidate>[correct, ...distractors];
    choices.shuffle(effectiveRandom);
    return choices;
  }
}
