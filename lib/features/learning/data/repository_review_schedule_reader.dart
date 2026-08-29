import '../../../core/engine/fsrs6_engine.dart';
import '../../../models/word.dart';
import '../application/review_schedule_reader.dart';
import 'review_schedule_repository.dart';

/// 基于正式复习排程仓储的只读展示适配器。
class RepositoryReviewScheduleReader extends ReviewScheduleReader {
  RepositoryReviewScheduleReader({required this._repository}) {
    _repository.addListener(notifyListeners);
  }

  final ReviewScheduleRepository _repository;

  @override
  FsrsCard? cardFor(String word) => _repository.cardFor(word);

  @override
  String getStatusText(FsrsCard card) => _repository.getStatusText(card);

  @override
  String getDifficultyText(FsrsCard card) => _repository.getDifficultyText(card);

  @override
  int get todayLearnCount => _repository.todayLearnCount;

  @override
  int get todayReviewCount => _repository.todayReviewCount;

  @override
  int get dueCount => _repository.dueCount;

  @override
  int get activeDateCount => _repository.activeDateCount;

  @override
  Map<String, int> get memoryStats => _repository.memoryStats;

  @override
  List<Word> dueWordsFor(Iterable<Word> words) => _repository.dueWordsFor(words);

  @override
  void dispose() {
    _repository.removeListener(notifyListeners);
    super.dispose();
  }
}
