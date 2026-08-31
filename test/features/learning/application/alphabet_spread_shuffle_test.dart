// 字母分散洗牌测试：同首字母不连续出现
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/learning/application/alphabet_spread_shuffle.dart';
import 'package:word_app/models/word.dart';

void main() {
  List<Word> words(List<String> spellings) => [
    for (var i = 0; i < spellings.length; i++) Word(id: i, word: spellings[i]),
  ];

  test('同一首字母不连续出现（大量同首字母词）', () {
    final input = words(['apple', 'apply', 'apt', 'axe', 'banana', 'cat', 'dog', 'duck', 'elephant']);
    final result = alphabetSpreadShuffle(input);
    for (var i = 1; i < result.length; i++) {
      expect(
        result[i].word[0].toLowerCase() == result[i - 1].word[0].toLowerCase(),
        isFalse,
        reason: '位置 $i 出现连续同首字母: ${result[i - 1].word} → ${result[i].word}',
      );
    }
  });

  test('保留全部单词不丢失', () {
    final input = words(['a1', 'a2', 'a3', 'b1', 'c1', 'c2']);
    final result = alphabetSpreadShuffle(input);
    expect(result.length, input.length);
    final names = result.map((w) => w.word).toSet();
    expect(names, {'a1', 'a2', 'a3', 'b1', 'c1', 'c2'});
  });

  test('单词数少于 3 时不崩', () {
    expect(alphabetSpreadShuffle(words(['x1'])).length, 1);
    expect(alphabetSpreadShuffle(words([])).length, 0);
  });
}
