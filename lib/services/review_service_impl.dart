// ReviewServiceImpl — 复习流程服务实现

import '../engine/core_engine.dart' show WordChoicePair;
import '../engine/distractor_engine.dart';
import '../engine/fsrs6_engine.dart' show FsrsRating, Fsrs6Engine;
import '../models/bb_word_process.dart';
import '../models/word.dart';
import '../repositories/word_repository.dart';
import 'audio_service.dart';
import 'review_service.dart';

/// 复习流程服务实现
class ReviewServiceImpl implements ReviewService {
  final Fsrs6Engine _fsrsEngine = Fsrs6Engine();

  List<BBWordProcess> _dueWords = [];
  List<String> _queue = [];
  int _currentIndex = 0;
  bool _initialized = false;

  // wordRepo 和 audioService 通过构造函数注入，供未来扩展使用
  // ignore: unused_field
  final WordRepository _wordRepo;
  // ignore: unused_field
  final AudioService _audioService;

  ReviewServiceImpl({
    required WordRepository wordRepo,
    required AudioService audioService,
  })  : _wordRepo = wordRepo,
        _audioService = audioService;

  // === 新增方法：兼容旧 ReviewSession 接口 ===

  @override
  void init(List<BBWordProcess> dueWords) {
    _dueWords = dueWords;
    _queue = dueWords.map((e) => e.word).toList();
    _currentIndex = 0;
    _initialized = true;
  }

  @override
  Word? currentWord() {
    if (!_initialized || _currentIndex < 0 || _currentIndex >= _queue.length) {
      return null;
    }
    final word = _queue[_currentIndex];
    // 从 dueWords 中找到对应的 BBWordProcess，转换为 Word
    final process = _dueWords.firstWhere(
      (p) => p.word == word,
      orElse: () => BBWordProcess(word: word),
    );
    return Word(
      id: process.wordId,
      word: process.word,
      interpret: process.interpret,
      ukPron: process.ukPron,
      usPron: process.usPron,
      example: process.example,
    );
  }

  @override
  int get totalNum => _queue.length;

  @override
  List<WordChoicePair> confuseItemsForChoice(Word current) {
    final allWords = _dueWords
        .map((p) => {'word': p.word, 'interpret': p.interpret})
        .toList();
    final candidates = DistractorEngine().generate(
      targetWord: current.word,
      targetInterpret: current.interpret,
      allWords: allWords,
      count: 3,
    );
    return candidates
        .map((c) => WordChoicePair(current.word, c.interpret))
        .toList();
  }

  @override
  void iDontKnow() {
    if (_currentIndex < _queue.length) {
      _fsrsEngine.learn(_queue[_currentIndex], FsrsRating.again);
      _advance();
    }
  }

  @override
  void iMayKnow() {
    if (_currentIndex < _queue.length) {
      _fsrsEngine.learn(_queue[_currentIndex], FsrsRating.hard);
      _advance();
    }
  }

  @override
  void iReallyKnow() {
    if (_currentIndex < _queue.length) {
      _fsrsEngine.learn(_queue[_currentIndex], FsrsRating.good);
      _advance();
    }
  }

  @override
  void tooEasy() {
    if (_currentIndex < _queue.length) {
      _fsrsEngine.learn(_queue[_currentIndex], FsrsRating.easy);
      _advance();
    }
  }

  void _advance() {
    _currentIndex++;
  }

  // === 原有方法 ===

  @override
  Future<void> loadReviewQueue() async {
    _currentIndex = 0;
  }

  @override
  String? get currentWordString {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return null;
    return _queue[_currentIndex];
  }

  @override
  Future<void> rateCurrent(int quality) async {
    final rating = FsrsRating.values[quality.clamp(0, 3)];
    if (_currentIndex < _queue.length) {
      _fsrsEngine.learn(_queue[_currentIndex], rating);
    }
  }

  @override
  bool get hasMore => _currentIndex < _queue.length - 1;

  @override
  (int current, int total) get progress => (_currentIndex, _queue.length);

  @override
  Future<void> rateWord(String word, FsrsRating rating) async {
    _fsrsEngine.learn(word, rating);
  }

  @override
  Future<void> resetCard(String word) async {
    // FSRS 重置：重新创建卡片
  }
}
