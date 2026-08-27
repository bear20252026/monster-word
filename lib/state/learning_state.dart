// 由账号4生成
// 遗留学习外观：向尚未迁出的页面提供兼容 API；学习会话行为已委托给专用状态。
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/wordbook_database.dart' show WordBookDatabase;
import '../engine/core_engine.dart' show WordChoicePair;
import '../engine/fsrs6_engine.dart';
import '../features/learning/data/learning_progress_repository.dart';
import '../features/learning/data/learning_queue_repository.dart';
import '../features/learning/data/review_schedule_repository.dart';
import '../features/learning/domain/queue_word_lists.dart';
import '../features/learning/presentation/learning_session_state.dart';
import '../models/book.dart';
import '../models/word.dart';
import '../repositories/fav_repository.dart';
import '../repositories/mastered_repository.dart';

/// 遗留学习状态兼容外观。
///
/// 新学习代码应使用 [LearningSessionState]、[LearningQueueRepository]、
/// [LearningProgressRepository] 与 [ReviewScheduleRepository]。本类仅在尚未迁出的
/// 页面继续需要收藏、掌握、账号和旧学习会话 API 时提供稳定转发，避免双份队列与
/// 双份评分推进。
class LearningState extends ChangeNotifier {
  LearningState({
    required FavRepository favRepository,
    required MasteredRepository masteredRepository,
    ReviewScheduleRepository? reviewSchedule,
    LearningProgressRepository? progressRepository,
    LearningQueueRepository? queueRepository,
    LearningSessionState? session,
  }) : _favRepository = favRepository,
       _masteredRepository = masteredRepository,
       _reviewSchedule = reviewSchedule ?? ReviewScheduleRepository(),
       _progressRepository = progressRepository ?? LearningProgressRepository(),
       _queueRepository =
           queueRepository ??
           LearningQueueRepository(
             wordSource: WordBookLearningQueueWordSource(database: WordBookDatabase.instance),
             favRepository: favRepository,
           ) {
    _ownsSession = session == null;
    _session =
        session ??
        LearningSessionState(
          queueRepository: _queueRepository,
          progressRepository: _progressRepository,
          reviewSchedule: _reviewSchedule,
        );
    _reviewSchedule.addListener(_notifyChanged);
    _session.addListener(_notifyChanged);
    unawaited(_reviewSchedule.initialize());
  }

  final FavRepository _favRepository;
  final MasteredRepository _masteredRepository;
  final ReviewScheduleRepository _reviewSchedule;
  final LearningProgressRepository _progressRepository;
  final LearningQueueRepository _queueRepository;
  late final LearningSessionState _session;
  late final bool _ownsSession;

  /// 供渐进迁移中的页面与读取状态消费专用学习会话；新代码不应再从此类读取队列。
  LearningSessionState get session => _session;

  Book? get currentBook => _session.currentBook;
  List<Word> get queue => _session.queue;
  int get currentIndex => _session.currentIndex;
  int get total => _session.total;
  bool get showAnswer => _session.showAnswer;
  List<WordChoicePair> get choices => _session.choices;
  Word? get currentWord => _session.currentWord;
  int get learnedNum => _session.learnedNum;

  /// 今日待复习数量。正式复习直接通过 [ReviewScheduleRepository] 获取调度数据。
  int get dueCount => _reviewSchedule.dueCount;
  int get todayLearnCount => _reviewSchedule.todayLearnCount;
  int get todayReviewCount => _reviewSchedule.todayReviewCount;
  int get consecutiveDays => _reviewSchedule.consecutiveDays;

  bool isFavorite(String word) => _favRepository.isFavorite(word);
  bool isMastered(String word) => _masteredRepository.isMastered(word);
  int get favoriteCount => _favRepository.favoriteCount;
  int get masteredCount => _masteredRepository.masteredCount;

  Future<bool> toggleFavorite(String word) async {
    await _favRepository.toggleFavorite(word);
    notifyListeners();
    return _favRepository.isFavorite(word);
  }

  Future<bool> toggleMastered(String word) async {
    await _masteredRepository.toggleMastered(word);
    notifyListeners();
    return _masteredRepository.isMastered(word);
  }

  Future<List<Word>> getFavoriteWords() {
    return _queueRepository.loadFavoriteWords(currentQueue: queue);
  }

  Future<void> loadFavoritesForLearning({int limit = 50}) {
    return _session.loadFavorites(limit: limit);
  }

  Future<List<Word>> getMasteredWords() async {
    final masteredWords = await _masteredRepository.getMasteredWords();
    return queue.where((word) => masteredWords.contains(word.word)).toList(growable: false);
  }

  Future<void> loadBook(Book book, {int limit = 50, bool shuffle = true}) {
    return _session.loadBook(book, limit: limit, shuffle: shuffle);
  }

  void flip() => _session.flip();

  /// 兼容旧页面的学习会话评分：保留 Leitner 推进后向独立调度仓储写入该词的语义。
  Future<void> rate(FsrsRating rating) => _session.rate(rating);

  /// 正式复习评分兼容入口；正式路径使用 ReviewRatingWriter 直接调用调度仓储。
  Future<void> rateReviewWord({required String word, required FsrsRating rating}) {
    return _reviewSchedule.rateWord(word: word, rating: rating);
  }

  void relearn() => _session.relearn();
  void next() => _session.next();
  void previous() => _session.previous();
  void jumpTo(int index) => _session.jumpTo(index);

  /// 保留旧调用点。音频资源已由音频服务和页面状态管理，此处无会话级资源需要释放。
  void exitLearning() {}

  FsrsCard? get currentCard {
    final word = currentWord;
    return word == null ? null : _reviewSchedule.cardFor(word.word);
  }

  FsrsCard? getCard(String word) => _reviewSchedule.cardFor(word);

  Map<String, dynamic>? get currentPrediction {
    final word = currentWord;
    return word == null ? null : _reviewSchedule.predictionFor(word.word);
  }

  Map<String, int> get memoryStats => _reviewSchedule.memoryStats;

  Map<String, int> get todayStats {
    final stats = memoryStats;
    return {
      'learned': total - (stats['new'] ?? 0),
      'due': stats['due'] ?? 0,
      'total': stats['total'] ?? 0,
      'mature': stats['mature'] ?? 0,
    };
  }

  List<Word> get dueWords => _reviewSchedule.dueWordsFor(queue);

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  Future<bool> login(String username, String password) async {
    _isLoggedIn = true;
    notifyListeners();
    return true;
  }

  Future<bool> phoneLogin(String phone, String code) async {
    _isLoggedIn = true;
    notifyListeners();
    return true;
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }

  bool _hasShownInitGuide = false;
  bool get hasShownInitGuide => _hasShownInitGuide;

  Future<void> setHasShownInitGuide(bool value) async {
    _hasShownInitGuide = value;
  }

  int get masteredNum => _masteredRepository.masteredCount;
  int get notLearnedNum => total - learnedNum;
  int get reviewingNum => _reviewSchedule.dueCount;
  int get totalLearnedDays => _reviewSchedule.activeDateCount;

  QueueWordLists get queueWordLists => QueueWordLists.fromQueue(
    queue: queue,
    isLearned: (word) => _reviewSchedule.cardFor(word.word) != null,
    isReviewing: (word) {
      final card = _reviewSchedule.cardFor(word.word);
      return card != null && card.difficulty <= 5.0;
    },
  );

  Future<List<Word>> getLearnedWords() async => queueWordLists.learnedWords;

  Future<List<Word>> getMasteredWordsBySrs() async {
    return queue
        .where((word) {
          final card = _reviewSchedule.cardFor(word.word);
          return card != null && card.difficulty > 5.0;
        })
        .toList(growable: false);
  }

  Future<List<Word>> getNotLearnedWords() async => queueWordLists.notLearnedWords;
  Future<List<Word>> getReviewingWords() async => queueWordLists.reviewingWords;
  Future<List<Word>> getWordsByBook(int bookId) => _queueRepository.loadWordsByBook(bookId);

  void _notifyChanged() => notifyListeners();

  @override
  void dispose() {
    _reviewSchedule.removeListener(_notifyChanged);
    _session.removeListener(_notifyChanged);
    if (_ownsSession) {
      _session.dispose();
    }
    super.dispose();
  }
}
