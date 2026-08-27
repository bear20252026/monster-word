import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/data/learning_progress_repository.dart';
import 'package:word_app/features/learning/data/learning_queue_repository.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/features/learning/presentation/learning_queue_state.dart';
import 'package:word_app/features/learning/presentation/learning_statistics_state.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/repositories/fav_repository.dart';
import 'package:word_app/repositories/mastered_repository.dart';
import 'package:word_app/state/learning_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('rateReviewWord 只更新实际复习词，不推进遗留学习队列', () async {
    final state = LearningState(favRepository: _FakeFavRepository(), masteredRepository: _FakeMasteredRepository());
    await Future<void>.delayed(Duration.zero);
    final legacyQueueWord = Word(word: 'legacy-queue');
    state.queue.add(legacyQueueWord);

    await state.rateReviewWord(word: 'reviewed-word', rating: FsrsRating.good);

    expect(state.currentWord, same(legacyQueueWord));
    expect(state.currentIndex, 0);
    expect(state.getCard('reviewed-word'), isNotNull);
    expect(state.getCard('legacy-queue'), isNull);
    expect(state.todayLearnCount, 1);

    await state.rateReviewWord(word: 'reviewed-word', rating: FsrsRating.again);

    expect(state.todayLearnCount, 1);
    expect(state.todayReviewCount, 1);
  });

  test('队列与统计读取快照隔离遗留可变队列并组合独立复习调度', () async {
    final schedule = ReviewScheduleRepository();
    await schedule.initialize();
    final legacy = LearningState(
      favRepository: _FakeFavRepository(),
      masteredRepository: _FakeMasteredRepository(),
      reviewSchedule: schedule,
    );
    legacy.queue.add(Word(word: 'first'));

    final queue = LearningQueueState()..synchronizeFrom(legacy.session);
    legacy.queue.add(Word(word: 'later'));
    final statistics = LearningStatisticsState()..synchronize(queue: queue.snapshot, schedule: schedule);

    expect(queue.words.map((word) => word.word), ['first']);
    expect(statistics.total, 1);
    expect(statistics.dueCount, 0);
    expect(statistics.memoryStats['total'], 0);
  });

  test('专用学习会话独立完成词书加载、候选生成与评分推进', () async {
    final schedule = ReviewScheduleRepository();
    final session = LearningSessionState(
      queueRepository: LearningQueueRepository(
        wordSource: _FakeWordSource([
          Word(id: 1, word: 'first', interpret: '第一'),
          Word(id: 2, word: 'second', interpret: '第二'),
        ]),
        favRepository: _FakeFavRepository(),
      ),
      progressRepository: LearningProgressRepository(),
      reviewSchedule: schedule,
    );

    await session.loadBook(Book(id: 1, code: 'TEST', name: '测试', wordCount: 2), shuffle: false);
    expect(session.currentWord?.word, 'first');
    expect(session.choices.where((choice) => choice.word == 'first'), hasLength(1));

    await session.rate(FsrsRating.good);

    expect(schedule.cardFor('first'), isNotNull);
    expect(session.currentWord?.word, 'second');
  });

  test('学习会话兼容外观委托队列加载、候选生成与评分推进', () async {
    final source = _FakeWordSource([
      Word(id: 1, word: 'first', interpret: '第一'),
      Word(id: 2, word: 'second', interpret: '第二'),
    ]);
    final schedule = ReviewScheduleRepository();
    final state = LearningState(
      favRepository: _FakeFavRepository(),
      masteredRepository: _FakeMasteredRepository(),
      reviewSchedule: schedule,
      queueRepository: LearningQueueRepository(wordSource: source, favRepository: _FakeFavRepository()),
    );

    await state.loadBook(Book(id: 1, code: 'TEST', name: '测试', wordCount: 2), shuffle: false);
    final first = state.currentWord;

    expect(first?.word, 'first');
    expect(state.choices.where((choice) => choice.word == first?.word), hasLength(1));

    await state.rate(FsrsRating.good);

    expect(schedule.cardFor('first'), isNotNull);
    expect(state.currentWord?.word, 'second');
  });
}

class _FakeWordSource implements LearningQueueWordSource {
  _FakeWordSource(this._words);

  final List<Word> _words;

  @override
  Future<List<Word>> getWordsByBook(int bookId, {required int limit, required int offset}) async {
    return List<Word>.from(_words);
  }

  @override
  Future<List<Word>> getWordsByNames(Iterable<String> words) async => const [];
}

class _FakeMasteredRepository implements MasteredRepository {
  final Set<String> _words = {};

  @override
  Future<Set<String>> getMasteredWords() async => Set<String>.from(_words);

  @override
  bool isMastered(String word) => _words.contains(word);

  @override
  int get masteredCount => _words.length;

  @override
  Future<void> toggleMastered(String word) async {
    if (_words.contains(word)) {
      _words.remove(word);
    } else {
      _words.add(word);
    }
  }
}

class _FakeFavRepository implements FavRepository {
  final Set<String> _words = {};

  @override
  Future<void> addFavorite(String word) async {
    _words.add(word);
  }

  @override
  int get favoriteCount => _words.length;

  @override
  int get favoriteSentenceCount => 0;

  @override
  Future<Set<String>> getFavoriteWords() async => Set<String>.from(_words);

  @override
  bool isFavorite(String word) => _words.contains(word);

  @override
  Future<void> removeFavorite(String word) async {
    _words.remove(word);
  }

  @override
  Future<void> toggleFavorite(String word) async {
    if (_words.contains(word)) {
      _words.remove(word);
    } else {
      _words.add(word);
    }
  }

  @override
  Future<bool> addFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) async => false;

  @override
  Future<List<Map<String, dynamic>>> getFavoriteSentences() async => const [];

  @override
  Future<bool> isFavoriteSentence(int wordId, String sentenceId) async => false;

  @override
  Future<bool> removeFavoriteSentence(int wordId, String sentenceId) async => false;

  @override
  Future<bool> toggleFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) async => false;
}
