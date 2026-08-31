// 学习队列字母分散洗牌（2026-08-31 用户需求：避免同首字母连续出现）
import 'dart:math';

import 'package:word_app/models/word.dart';

/// 贪心分散洗牌：每步从「首字母 != 上一个输出」的非空桶中选剩余最多的词；
/// 若所有非空桶都与上一个同首字母（极端：只剩一个字母桶），才允许同字母。
/// 结果：同首字母尽可能分散，且不丢失任何单词。
List<Word> alphabetSpreadShuffle(List<Word> words, {Random? random}) {
  final rng = random ?? Random();
  if (words.length < 3) return List<Word>.from(words)..shuffle(rng);

  // 分桶（首字母小写分组），桶内随机排序
  final buckets = <String, List<Word>>{};
  for (final w in words) {
    final key = w.word.isEmpty ? '#' : w.word[0].toLowerCase();
    (buckets[key] ??= []).add(w);
  }
  for (final b in buckets.values) {
    b.shuffle(rng);
  }

  String? lastKey;
  final result = <Word>[];
  while (result.length < words.length) {
    // 候选：非空桶
    final candidates = buckets.entries.where((e) => e.value.isNotEmpty).toList();
    if (candidates.isEmpty) break;

    // 优先取与上一个不同首字母的桶中剩余最多的
    final preferred = candidates.where((e) => e.key != lastKey).toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final chosen = (preferred.isNotEmpty ? preferred : candidates).first;
    result.add(chosen.value.removeLast());
    lastKey = chosen.key;
  }
  return result;
}
