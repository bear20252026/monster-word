import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/application/review_session_question_factory.dart';
import 'package:word_app/models/mw_word_process.dart';
import 'package:word_app/models/word.dart';

void main() {
  const factory = ReviewSessionQuestionFactory();

  group('ReviewSessionQuestionFactory', () {
    test('将读取层词条完整转换为正式复习过程模型', () {
      final processes = factory.createProcesses([
        Word(
          id: 7,
          word: 'reviewed',
          interpret: '复习过的',
          usPron: '/rɪˈvjuːd/',
          ukPron: '/rɪˈvjuːd/',
          example: 'The word was reviewed.',
        ),
      ]);

      expect(processes, hasLength(1));
      final process = processes.single;
      expect(process.word, 'reviewed');
      expect(process.wordId, 7);
      expect(process.interpret, '复习过的');
      expect(process.usPron, '/rɪˈvjuːd/');
      expect(process.ukPron, '/rɪˈvjuːd/');
      expect(process.example, 'The word was reviewed.');
    });

    test('从当前题和余下词池生成包含正确答案的四选一候选项', () {
      final current = MwWordProcess(word: 'correct', interpret: '正确释义');
      final choices = factory.createChoices(
        currentWord: current,
        reviewWords: [
          current,
          MwWordProcess(word: 'other-1', interpret: '干扰释义一'),
          MwWordProcess(word: 'other-2', interpret: '干扰释义二'),
          MwWordProcess(word: 'other-3', interpret: '干扰释义三'),
        ],
      );

      expect(choices, hasLength(4));
      expect(choices.where((choice) => choice.word == 'correct'), hasLength(1));
      expect(choices.where((choice) => choice.interpret == '正确释义'), hasLength(1));
    });

    test('没有当前题时不产生展示候选项', () {
      final choices = factory.createChoices(currentWord: null, reviewWords: const []);

      expect(choices, isEmpty);
    });
  });
}
