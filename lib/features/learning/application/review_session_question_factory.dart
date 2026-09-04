import 'package:word_app/core/engine/core_engine.dart' show WordChoicePair;
import 'package:word_app/core/engine/super_memory_engine.dart';
import 'package:word_app/models/mw_word_process.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/domain/choice_generator.dart';

/// 正式复习会话的题目数据工厂。
///
/// 负责将读取层的 [Word] 转换为本地 [SuperMemoryEngine] 所需的过程模型，并从
/// 引擎当前题目与余下词池生成展示候选项。它不推进引擎、不写入评分，也不维护
/// 页面交互状态。
class ReviewSessionQuestionFactory {
  const ReviewSessionQuestionFactory();

  List<MwWordProcess> createProcesses(Iterable<Word> words) {
    return words
        .map(
          (word) => MwWordProcess(
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
    required MwWordProcess? currentWord,
    required Iterable<MwWordProcess> reviewWords,
  }) {
    if (currentWord == null) return const [];

    final choices = ChoiceGenerator.generate(
      correct: ChoiceCandidate(word: currentWord.word, interpret: currentWord.interpret),
      candidates: reviewWords.map((word) => ChoiceCandidate(word: word.word, interpret: word.interpret)),
    );
    return choices.map((choice) => WordChoicePair(choice.word, choice.interpret)).toList();
  }
}
