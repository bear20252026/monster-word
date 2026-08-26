// 单元测试：LearnState 学习流程状态管理
// 复现 bug：点击"开始学习"后立即显示"学习完成"

import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/services/audio_service.dart';
import 'package:word_app/services/learn_service.dart';
import 'package:word_app/state/learn_state.dart';

/// 模拟 LearnService
class MockLearnService implements LearnService {
  List<Word> _queue = [];
  int _currentIndex = 0;
  bool _loadBookCalled = false;

  bool get loadBookCalled => _loadBookCalled;

  @override
  Future<void> loadBook(int bookId, {int limit = 50, int offset = 0, bool shuffle = true}) async {
    _loadBookCalled = true;
    // 模拟加载 5 个单词
    _queue = List.generate(5, (i) => Word(id: i + 1, word: 'word$i', interpret: '[{"def":[{"cn":"释义$i"}]}]'));
    _currentIndex = 0;
  }

  @override
  Word? get currentWord {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return null;
    return _queue[_currentIndex];
  }

  @override
  List<String> get multipleChoiceOptions => [currentWord?.word ?? ''];

  @override
  bool checkAnswer(String selected) => currentWord?.word == selected;

  @override
  String get correctAnswer => currentWord?.word ?? '';

  @override
  Future<void> rateWord(int quality) async {}

  @override
  Future<void> nextWord() async {
    if (_currentIndex < _queue.length - 1) _currentIndex++;
  }

  @override
  bool get hasMoreWords => _currentIndex < _queue.length - 1;

  @override
  (int current, int total) get progress => (_currentIndex + 1, _queue.length);

  @override
  Future<void> playCurrentAudio() async {}

  @override
  Future<List<String>> getFavoriteWords() async => [];

  @override
  List<Word> get queue => _queue;
}

/// 模拟 AudioService
class MockAudioService implements AudioService {
  @override
  Future<void> playWordAudio(String word, {String accent = 'us', String? audioUrl}) async {}

  @override
  Future<void> playFromUrl(String url) async {}

  @override
  Future<void> stop() async {}

  @override
  bool get isPlaying => false;

  @override
  void dispose() {}
}

/// 模拟空词书
class EmptyMockLearnService implements LearnService {
  @override
  Future<void> loadBook(int bookId, {int limit = 50, int offset = 0, bool shuffle = true}) async {}

  @override
  Word? get currentWord => null;

  @override
  List<String> get multipleChoiceOptions => [];

  @override
  bool checkAnswer(String selected) => false;

  @override
  String get correctAnswer => '';

  @override
  Future<void> rateWord(int quality) async {}

  @override
  Future<void> nextWord() async {}

  @override
  bool get hasMoreWords => false;

  @override
  (int current, int total) get progress => (0, 0);

  @override
  Future<void> playCurrentAudio() async {}

  @override
  Future<List<String>> getFavoriteWords() async => [];

  @override
  List<Word> get queue => [];
}

void main() {
  group('LearnState.loadBook', () {
    test('加载词书后 currentWord 不应为 null（复现学习立即完成 bug）', () async {
      // ✅ 复现 bug：如果 loadBook 被调用后 currentWord 仍为 null，
      // 则 LearnPage 会立即显示 _CompletionScreen
      final mockService = MockLearnService();
      final mockAudio = MockAudioService();
      final state = LearnState(learnService: mockService, audioService: mockAudio);

      final testBook = Book(id: 1, name: '测试词书', code: 'test', wordCount: 5);

      // 初始状态：currentWord 为 null
      expect(state.currentWord, isNull);

      // 加载词书
      await state.loadBook(testBook);

      // ✅ 修复后：loadBook 成功后 currentWord 不应为 null
      expect(mockService.loadBookCalled, isTrue, reason: 'loadBook 应被调用');
      expect(state.currentWord, isNotNull, reason: '加载词书后 currentWord 不应为 null');
      expect(state.currentWord?.word, 'word0');
      expect(state.queue, hasLength(5));
    });

    test('加载词书后 progress 应显示正确进度', () async {
      final mockService = MockLearnService();
      final mockAudio = MockAudioService();
      final state = LearnState(learnService: mockService, audioService: mockAudio);

      final testBook = Book(id: 1, name: '测试词书', code: 'test', wordCount: 5);
      await state.loadBook(testBook);

      expect(state.progress, (1, 5));
    });

    test('加载空词书时 currentWord 应为 null', () async {
      final mockService = EmptyMockLearnService();
      final mockAudio = MockAudioService();
      final state = LearnState(learnService: mockService, audioService: mockAudio);

      final testBook = Book(id: 999, name: '空词书', code: 'empty', wordCount: 0);
      await state.loadBook(testBook);

      expect(state.currentWord, isNull);
      expect(state.queue, isEmpty);
    });
  });

  group('LearnState.nextWord', () {
    test('调用 nextWord 后应前进到下一个单词', () async {
      final mockService = MockLearnService();
      final mockAudio = MockAudioService();
      final state = LearnState(learnService: mockService, audioService: mockAudio);

      final testBook = Book(id: 1, name: '测试词书', code: 'test', wordCount: 5);
      await state.loadBook(testBook);

      expect(state.currentWord?.word, 'word0');

      state.next();
      expect(state.currentWord?.word, 'word1');

      state.next();
      expect(state.currentWord?.word, 'word2');
    });

    test('到达最后一个单词后 hasMoreWords 应为 false', () async {
      final mockService = MockLearnService();
      final mockAudio = MockAudioService();
      final state = LearnState(learnService: mockService, audioService: mockAudio);

      final testBook = Book(id: 1, name: '测试词书', code: 'test', wordCount: 5);
      await state.loadBook(testBook);

      // 跳到最后一个
      for (int i = 0; i < 4; i++) {
        state.next();
      }

      expect(state.currentWord?.word, 'word4');
      expect(state.hasMoreWords, isFalse);
    });
  });

  group('LearnState.choices', () {
    test('加载词书后始终提供一个正确项与四个唯一候选项', () async {
      final state = LearnState(learnService: MockLearnService(), audioService: MockAudioService());
      final testBook = Book(id: 1, name: '测试词书', code: 'test', wordCount: 5);

      await state.loadBook(testBook);

      expect(state.choices, hasLength(4));
      expect(state.currentWord, isNotNull);
      expect(state.choices.where((choice) => choice.word == state.currentWord!.word), hasLength(1));
      expect(state.choices.map((choice) => choice.interpret).toSet(), hasLength(4));
    });

    test('切换到下一词时候选正确项随会话当前词刷新', () async {
      final state = LearnState(learnService: MockLearnService(), audioService: MockAudioService());
      final testBook = Book(id: 1, name: '测试词书', code: 'test', wordCount: 5);

      await state.loadBook(testBook);
      final firstWord = state.currentWord!.word;
      state.next();

      expect(state.currentWord!.word, isNot(firstWord));
      expect(state.choices, hasLength(4));
      expect(state.choices.where((choice) => choice.word == state.currentWord!.word), hasLength(1));
    });
  });
}
