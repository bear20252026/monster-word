import '../../../engine/core_engine.dart' show WordChoicePair;
import '../../../engine/super_memory_engine.dart';
import '../../../models/bb_word_process.dart';
import '../../../models/word.dart';
import '../domain/choice_generator.dart';

/// 正式复习会话的题目数据工厂。
///
/// 负责将读取层的 [Word] 转换为本地 [SuperMemoryEngine] 所需的过程模型，并从
/// 引擎当前题目与余下词池生成展示候选项。它不推进引擎、不写入评分，也不维护
/// 页面交互状态。
class ReviewSessionQuestionFactory {
  const ReviewSessionQuestionFactory();

  List<BBWordProcess> createProcesses(Iterable<Word> words) {
    return words
        .map(
          (word) => BBWordProcess(
            word: word.word,
            wordId: word.id,
            interpret: word.interpret,
            usPron: word.usPron,
            ukPron: word.ukPron,
            example: word.example,
          ),
        )
        .toList();
  }

  List<WordChoicePair> createChoices({
    required BBWordProcess? currentWord,
    required Iterable<BBWordProcess> reviewWords,
  }) {
    if (currentWord == null) return const [];

    final choices = ChoiceGenerator.generate(
      correct: ChoiceCandidate(word: currentWord.word, interpret: currentWord.interpret),
      candidates: reviewWords.map((word) => ChoiceCandidate(word: word.word, interpret: word.interpret)),
    );
    return choices.map((choice) => WordChoicePair(choice.word, choice.interpret)).toList();
  }
}
