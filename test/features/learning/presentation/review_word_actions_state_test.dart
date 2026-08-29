import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/application/favorites_port.dart';
import 'package:word_app/features/learning/application/mastered_words_reader.dart';
import 'package:word_app/features/learning/application/mastered_writer_port.dart';
import 'package:word_app/features/learning/presentation/review_word_action_coordinator.dart';
import 'package:word_app/features/learning/presentation/review_word_action_feedback.dart';
import 'package:word_app/features/learning/presentation/review_word_actions_state.dart';
import 'package:word_app/models/bb_word_process.dart';
import 'package:word_app/models/word.dart';

void main() {
  group('ReviewWordActionsState', () {
    test('同步真实收藏快照并持久化切换结果', () async {
      final favorites = _FakeFavoritesPort({'apple'});
      final masteredWords = <String>{};
      final state = ReviewWordActionsState(
        favoritesPort: favorites,
        masteredReader: _FakeMasteredWordsReader(masteredWords),
        masteredWriter: _FakeMasteredWriterPort(masteredWords),
      );

      await state.initialize();

      expect(state.initialized, isTrue);
      expect(state.isFavorite('apple'), isTrue);
      expect(await state.toggleFavorite('apple'), isFalse);
      expect(state.isFavorite('apple'), isFalse);
      expect(favorites.isFavorite('apple'), isFalse);
      expect(await state.toggleFavorite('banana'), isTrue);
      expect(state.isFavorite('banana'), isTrue);
      expect(favorites.isFavorite('banana'), isTrue);
    });

    test('手动掌握标记只添加一次，不会反转已掌握状态', () async {
      final masteredWords = <String>{};
      final masteredWriter = _FakeMasteredWriterPort(masteredWords);
      final state = ReviewWordActionsState(
        favoritesPort: _FakeFavoritesPort(const {}),
        masteredReader: _FakeMasteredWordsReader(masteredWords),
        masteredWriter: masteredWriter,
      );

      expect(await state.markManuallyMastered('reviewed'), isTrue);
      expect(state.isManuallyMastered('reviewed'), isTrue);
      expect(masteredWriter.isMastered('reviewed'), isTrue);
      expect(await state.markManuallyMastered('reviewed'), isFalse);
      expect(masteredWriter.toggleCalls, 1);
      expect(masteredWriter.isMastered('reviewed'), isTrue);
    });
  });

  group('ReviewWordActionCoordinator', () {
    test('收藏切换返回持久化结果和对应反馈意图', () async {
      final actions = ReviewWordActionsState(
        favoritesPort: _FakeFavoritesPort(const {}),
        masteredReader: _FakeMasteredWordsReader(<String>{}),
        masteredWriter: _FakeMasteredWriterPort(<String>{}),
      );
      final coordinator = ReviewWordActionCoordinator(
        wordActions: actions,
        currentWord: () => BBWordProcess(word: 'reviewed'),
        markCurrentWordAsKnown: () => true,
      );

      final added = await coordinator.toggleFavorite();
      final removed = await coordinator.toggleFavorite();

      expect(added.outcome, ReviewWordActionOutcome.favoriteAdded);
      expect(added.feedbackMessage, '已收藏 reviewed');
      expect(added.feedbackDuration, const Duration(seconds: 1));
      expect(removed.outcome, ReviewWordActionOutcome.favoriteRemoved);
      expect(removed.feedbackMessage, '已取消收藏');
    });

    test('手动掌握先推进会话，再以幂等方式持久化标记', () async {
      final actions = ReviewWordActionsState(
        favoritesPort: _FakeFavoritesPort(const {}),
        masteredReader: _FakeMasteredWordsReader(<String>{}),
        masteredWriter: _FakeMasteredWriterPort(<String>{}),
      );
      var advanceCalls = 0;
      final coordinator = ReviewWordActionCoordinator(
        wordActions: actions,
        currentWord: () => BBWordProcess(word: 'reviewed'),
        markCurrentWordAsKnown: () {
          advanceCalls++;
          return true;
        },
      );

      final first = await coordinator.markCurrentWordAsKnown();
      final repeated = await coordinator.markCurrentWordAsKnown();

      expect(first.outcome, ReviewWordActionOutcome.manuallyMastered);
      expect(first.feedbackMessage, '已标记掌握 reviewed');
      expect(repeated.outcome, ReviewWordActionOutcome.alreadyManuallyMastered);
      expect(repeated.feedbackMessage, isNull);
      expect(advanceCalls, 2);
    });

    test('没有当前词或持久化失败时返回明确的非成功结果', () async {
      final masteredWords = <String>{};
      final noWordCoordinator = ReviewWordActionCoordinator(
        wordActions: ReviewWordActionsState(
          favoritesPort: _FakeFavoritesPort(const {}),
          masteredReader: _FakeMasteredWordsReader(masteredWords),
          masteredWriter: _FakeMasteredWriterPort(masteredWords),
        ),
        currentWord: () => null,
        markCurrentWordAsKnown: () => true,
      );
      final failingCoordinator = ReviewWordActionCoordinator(
        wordActions: _ThrowingReviewWordActionsState(
          favoritesPort: _FakeFavoritesPort(const {}),
          masteredReader: _FakeMasteredWordsReader(masteredWords),
          masteredWriter: _FakeMasteredWriterPort(masteredWords),
        ),
        currentWord: () => BBWordProcess(word: 'reviewed'),
        markCurrentWordAsKnown: () => true,
      );

      final ignored = await noWordCoordinator.toggleFavorite();
      final failed = await failingCoordinator.toggleFavorite();

      expect(ignored.outcome, ReviewWordActionOutcome.ignored);
      expect(ignored.shouldShowFeedback, isFalse);
      expect(failed.outcome, ReviewWordActionOutcome.favoritePersistFailed);
      expect(failed.feedbackMessage, '收藏状态保存失败，请重试');
      expect(failed.feedbackDuration, const Duration(seconds: 4));
    });
  });
}

class _ThrowingReviewWordActionsState extends ReviewWordActionsState {
  _ThrowingReviewWordActionsState({
    required super.favoritesPort,
    required super.masteredReader,
    required super.masteredWriter,
  });

  @override
  Future<bool> toggleFavorite(String word) => Future<bool>.error(StateError('favorite unavailable'));
}

class _FakeMasteredWordsReader implements MasteredWordsReader {
  _FakeMasteredWordsReader([Iterable<String>? words]) : _words = {...?words};

  final Set<String> _words;

  @override
  Future<List<Word>> loadWords() async => _words.map((w) => Word(word: w)).toList();

  @override
  Future<List<String>> loadTexts() async => _words.toList();
}

class _FakeMasteredWriterPort implements MasteredWriterPort {
  _FakeMasteredWriterPort(this._words);

  final Set<String> _words;
  int toggleCalls = 0;

  @override
  Future<void> toggleMastered(String word) async {
    toggleCalls++;
    if (_words.contains(word)) {
      _words.remove(word);
    } else {
      _words.add(word);
    }
  }

  bool isMastered(String word) => _words.contains(word);
}

class _FakeFavoritesPort implements FavoritesPort {
  _FakeFavoritesPort(Iterable<String> words) : _words = {...words};

  final Set<String> _words;

  @override
  Future<Set<String>> getFavoriteWords() async => Set<String>.from(_words);

  @override
  bool isFavorite(String word) => _words.contains(word);

  @override
  Future<void> toggleFavorite(String word) async {
    if (_words.contains(word)) {
      _words.remove(word);
    } else {
      _words.add(word);
    }
  }
}
