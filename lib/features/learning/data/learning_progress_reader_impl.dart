import 'package:word_app/core/di/service_locator.dart';
import 'package:word_app/features/learning/application/learning_progress_reader.dart';
import 'package:word_app/features/learning/data/mastered_repository.dart';

/// [LearningProgressReader] 的具体实现。
///
/// 通过 [MasteredRepository] 获取全局已掌握词集，
/// 统计给定词集中已被掌握的单词数量。
class LearningProgressReaderImpl implements LearningProgressReader {
  const LearningProgressReaderImpl({required this._masteredRepository});

  factory LearningProgressReaderImpl.fromServiceLocator() =>
      LearningProgressReaderImpl(masteredRepository: sl<MasteredRepository>());

  final MasteredRepository _masteredRepository;

  @override
  Future<int> countLearnedWords(Iterable<String> wordTexts) async {
    final masteredWords = await _masteredRepository.getMasteredWords();
    if (masteredWords.isEmpty) return 0;
    return wordTexts.where(masteredWords.contains).length;
  }
}
