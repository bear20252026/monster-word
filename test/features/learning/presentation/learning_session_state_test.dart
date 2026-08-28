import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/data/learning_progress_repository.dart';
import 'package:word_app/features/learning/data/learning_queue_repository.dart';
import 'package:word_app/features/learning/application/mastered_words_reader.dart';
import 'package:word_app/features/learning/data/repository_review_schedule_reader.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';
import 'package:word_app/features/learning/presentation/learning_favorites_state.dart';
import 'package:word_app/features/learning/presentation/learning_mastered_state.dart';
import 'package:word_app/features/learning/presentation/learning_queue_state.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/features/learning/presentation/learning_statistics_state.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/repositories/fav_repository.dart';
import 'package:word_app/repositories/mastered_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('队列与统计读取快照隔离专用会话的后续导航', () async {
    final schedule = ReviewScheduleRepository();
    await schedule.initialize();
    final session = _sessionWithWords(
      words: [
        Word(id: 1, word: 'first'),
        Word(id: 2, word: 'later'),
      ],
      schedule: schedule,
    );
    await session.loadBook(_testBook, shuffle: false);

    final queue = LearningQueueState()..synchronizeFrom(session);
    session.next();
    final scheduleReader = RepositoryReviewScheduleReader(repository: schedule);
    final statistics = LearningStatisticsState()..synchronize(queue: queue.snapshot, schedule: scheduleReader);

    expect(queue.words.map((word) => word.word), ['first', 'later']);
    expect(queue.currentIndex, 0);
    expect(statistics.total, 2);
    expect(statistics.dueCount, 0);
    expect(statistics.memoryStats['total'], 0);
    scheduleReader.dispose();
  });

  test('会话不向页面暴露可变队列，并在退出时清理会话导航状态', () async {
    final session = _sessionWithWords(
      words: [
        Word(id: 1, word: 'first'),
        Word(id: 2, word: 'second'),
      ],
    );
    await session.loadBook(_testBook, shuffle: false);

    expect(session.progress, (1, 2));
    expect(session.hasMoreWords, isTrue);
    expect(() => session.queue.add(Word(id: 3, word: 'unexpected')), throwsUnsupportedError);

    session.next();
    expect(session.progress, (2, 2));
    expect(session.hasMoreWords, isFalse);

    session.exitLearning();
    expect(session.currentWord, isNull);
    expect(session.queue, isEmpty);
    expect(session.choices, isEmpty);
    expect(session.progress, (0, 0));
  });

  test('专用收藏状态刷新并切换收藏时更新可订阅计数', () async {
    final repository = _FakeFavRepository();
    await repository.addFavorite('saved');
    final favorites = LearningFavoritesState(
      favoriteRepository: repository,
      queueRepository: LearningQueueRepository(wordSource: _FakeWordSource(const []), favRepository: repository),
    );

    await favorites.refresh();
    expect(favorites.favoriteCount, 1);
    expect(favorites.isFavorite('saved'), isTrue);

    final isFavorite = await favorites.toggle('saved');
    expect(isFavorite, isFalse);
    expect(favorites.favoriteCount, 0);
  });

  test('专用掌握词状态刷新并切换掌握标记时更新可订阅计数', () async {
    final repository = _FakeMasteredRepository({'saved'});
    final mastered = LearningMasteredState(
      masteredWordsReader: _FakeMasteredWordsReader(repository),
      masteredRepository: repository,
    );

    await mastered.refresh();
    expect(mastered.masteredCount, 1);
    expect(mastered.isMastered('saved'), isTrue);

    final isMastered = await mastered.toggle('saved');
    expect(isMastered, isFalse);
    expect(mastered.masteredCount, 0);
  });

  test('专用学习会话独立完成词书加载、候选生成与评分推进', () async {
    final schedule = ReviewScheduleRepository();
    final session = _sessionWithWords(
      words: [
        Word(id: 1, word: 'first', interpret: '第一'),
        Word(id: 2, word: 'second', interpret: '第二'),
      ],
      schedule: schedule,
    );

    await session.loadBook(_testBook, shuffle: false);
    expect(session.currentWord?.word, 'first');
    expect(session.choices.where((choice) => choice.word == 'first'), hasLength(1));

    await session.rate(FsrsRating.good);

    expect(schedule.cardFor('first'), isNotNull);
    expect(session.currentWord?.word, 'second');
  });

  test('专用学习会话在收藏词为空时保留当前队列与词书', () async {
    final session = _sessionWithWords(words: [Word(id: 1, word: 'first')]);
    await session.loadBook(_testBook, shuffle: false);

    await session.loadFavorites();

    expect(session.currentBook, same(_testBook));
    expect(session.queue.map((word) => word.word), ['first']);
  });
}

final _testBook = Book(id: 1, code: 'TEST', name: '测试', wordCount: 2);

LearningSessionState _sessionWithWords({required List<Word> words, ReviewScheduleRepository? schedule}) {
  final favorites = _FakeFavRepository();
  return LearningSessionState(
    queueRepository: LearningQueueRepository(wordSource: _FakeWordSource(words), favRepository: favorites),
    progressRepository: LearningProgressRepository(),
    reviewSchedule: schedule ?? ReviewScheduleRepository(),
  );
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
  _FakeMasteredRepository([Iterable<String> initialWords = const []]) : _words = {...initialWords};

  final Set<String> _words;

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

class _FakeMasteredWordsReader implements MasteredWordsReader {
  _FakeMasteredWordsReader(this.repository);

  final MasteredRepository repository;

  @override
  Future<List<String>> loadTexts() async => (await repository.getMasteredWords()).toList();

  @override
  Future<List<Word>> loadWords() async => const [];
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
