// 由 Claude 团队生成 | Monster Word App
// LearnServiceImpl — 学习流程服务实现

import '../../models/word.dart';
import '../repositories/fav_repository.dart';
import '../repositories/word_repository.dart';
import 'audio_service.dart';
import 'learn_service.dart';

/// 学习流程服务实现
/// 
/// 通过 Repository 层访问数据，通过 AudioService 播放音频。
/// 不直接依赖具体数据库或播放器实现。
class LearnServiceImpl implements LearnService {
  final WordRepository _wordRepo;
  final AudioService _audioService;
  final FavRepository _favRepo;

  List<Word> _queue = [];
  int _currentIndex = 0;

  LearnServiceImpl({
    required WordRepository wordRepo,
    required AudioService audioService,
    required FavRepository favRepo,
  })  : _wordRepo = wordRepo,
        _audioService = audioService,
        _favRepo = favRepo;

  @override
  Future<void> loadBook(int bookId, {int limit = 50, int offset = 0, bool shuffle = true}) async {
    _queue = await _wordRepo.getWordsByBookId(bookId, limit: limit, offset: offset);
    if (shuffle) {
      _queue.shuffle();
    }
    _currentIndex = 0;
  }

  @override
  Word? get currentWord {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return null;
    return _queue[_currentIndex];
  }

  @override
  List<String> get multipleChoiceOptions {
    final word = currentWord;
    if (word == null) return [];
    // TODO: 实现4选1逻辑（当前词 + 3个干扰项）
    return [word.word];
  }

  @override
  bool checkAnswer(String selected) {
    final word = currentWord;
    if (word == null) return false;
    return word.word == selected;
  }

  @override
  String get correctAnswer {
    return currentWord?.word ?? '';
  }

  @override
  Future<void> rateWord(int quality) async {
    final word = currentWord;
    if (word == null) return;
    // TODO: 调用 SRS 引擎评分
    await _wordRepo.updateWordStatus(word.id, {'quality': quality});
  }

  @override
  Future<void> nextWord() async {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    }
  }

  @override
  bool get hasMoreWords => _currentIndex < _queue.length - 1;

  @override
  (int current, int total) get progress => (_currentIndex + 1, _queue.length);

  @override
  Future<void> playCurrentAudio() async {
    final word = currentWord;
    if (word == null) return;
    await _audioService.playWordAudio(word.word);
  }

  @override
  Future<List<String>> getFavoriteWords() async {
    final favSet = await _favRepo.getFavoriteWords();
    return favSet.toList();
  }

  @override
  List<Word> get queue => _queue;
}
