import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/application/review_queue_reader.dart';
import 'package:word_app/features/learning/data/repository_review_queue_reader.dart';
import 'package:word_app/features/learning/application/review_rating_writer.dart';
import 'package:word_app/features/learning/presentation/review_session_state.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/repositories/word_repository.dart';

void main() {
  group('ReviewSessionState', () {
    test('初始化后生成候选项，并将推进前的实际作答词提交给评分写入端口', () async {
      String? persistedWord;
      FsrsRating? persistedRating;
      final state = ReviewSessionState(
        queueReader: RepositoryReviewQueueReader(wordRepository: _UnusedWordRepository()),
        ratingWriter: ReviewRatingWriter(
          writeRating: ({required word, required rating}) async {
            persistedWord = word;
            persistedRating = rating;
          },
        ),
      );
      final words = [Word(id: 1, word: 'first', interpret: '第一'), Word(id: 2, word: 'second', interpret: '第二')];

      await state.initialize(ReviewQueueSnapshot(dueWords: words, queueWords: const []));
      final reviewedWord = state.currentWord;

      expect(state.loadPhase, ReviewSessionLoadPhase.ready);
      expect(state.isReady, isTrue);
      expect(state.total, 2);
      expect(state.done, 0);
      expect(reviewedWord, isNotNull);
      final reviewedWordText = reviewedWord!.word;
      expect(state.choices, hasLength(4));
      expect(state.choices.where((choice) => choice.word == reviewedWordText), hasLength(1));

      final wrongChoice = state.choices.firstWhere((choice) => choice.word != reviewedWordText);
      state.selectChoice(wrongChoice.word);
      expect(state.isWrongChoiceSelected(wrongChoice.word), isTrue);
      expect(state.selectedWrongChoice, wrongChoice.word);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(state.isWrongChoiceSelected(wrongChoice.word), isFalse);
      expect(state.selectedWrongChoice, isNull);

      state.revealAnswer();
      expect(state.showAnswer, isTrue);
      state.continueWithGoodRating();

      expect(persistedWord, reviewedWordText);
      expect(persistedRating, FsrsRating.good);
      expect(state.done, 1);
      expect(state.showAnswer, isFalse);
      expect(state.currentWord?.word, isNot(reviewedWordText));
    });

    test('初始化读取失败后保留错误状态而不是把页面当作复习完成', () async {
      final state = ReviewSessionState(
        queueReader: RepositoryReviewQueueReader(wordRepository: _ThrowingWordRepository()),
        ratingWriter: ReviewRatingWriter(writeRating: ({required word, required rating}) async {}),
      );

      await expectLater(
        state.initialize(const ReviewQueueSnapshot(dueWords: [], queueWords: [])),
        throwsA(isA<StateError>()),
      );

      expect(state.loadPhase, ReviewSessionLoadPhase.failed);
      expect(state.hasLoadError, isTrue);
      expect(state.loadError, isA<StateError>());
      expect(state.currentWord, isNull);
      expect(state.done, 0);
    });
  });
}

class _ThrowingWordRepository extends _UnusedWordRepository {
  @override
  Future<List<Word>> searchWords(String query, {int? limit}) async {
    throw StateError('word source unavailable');
  }
}

class _UnusedWordRepository implements WordRepository {
  @override
  Future<List<Word>> getRandomWords(int count, {int? excludeBookId}) => throw UnimplementedError();

  @override
  Future<Word?> getWordById(int id) => throw UnimplementedError();

  @override
  Future<Word?> getWordByText(String text) => throw UnimplementedError();

  @override
  Future<List<Word>> getWordsByBookId(int bookId, {int? limit, int? offset}) => throw UnimplementedError();

  @override
  Future<List<Word>> getWordsByIds(Iterable<int> ids) => throw UnimplementedError();

  @override
  Future<List<Word>> getWordsByTexts(Iterable<String> texts) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>?> getWordDetails(int wordId) => throw UnimplementedError();

  @override
  Future<List<Word>> searchWords(String query, {int? limit}) => throw UnimplementedError();

  @override
  Future<int> updateWordStatus(int wordId, Map<String, dynamic> status) => throw UnimplementedError();
}
