import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/application/review_word_details.dart';
import 'package:word_app/models/bb_word_process.dart';

void main() {
  test('正式复习词条映射为词典详情所需的 Word 字段', () {
    final reviewWord = BBWordProcess(
      wordId: 42,
      word: 'resilient',
      interpret: '有韧性的',
      usPron: 'rɪˈzɪliənt',
      ukPron: 'rɪˈzɪliənt',
      example: 'She remained resilient.',
    );

    final detailWord = reviewWord.toDictionaryWord();

    expect(detailWord.id, 42);
    expect(detailWord.word, 'resilient');
    expect(detailWord.mainWord, 'resilient');
    expect(detailWord.interpret, '有韧性的');
    expect(detailWord.usPron, 'rɪˈzɪliənt');
    expect(detailWord.ukPron, 'rɪˈzɪliənt');
    expect(detailWord.example, 'She remained resilient.');
    expect(detailWord.phrase, isEmpty);
    expect(detailWord.confuse, isEmpty);
  });
}
