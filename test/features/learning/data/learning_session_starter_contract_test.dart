import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/features/learning/application/learning_session_starter.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/application/choice_generator_port.dart';
import 'package:word_app/features/learning/application/learning_progress_port.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/features/learning/application/review_schedule_writer_port.dart';
import 'package:word_app/features/learning/presentation/learning_session_starter_impl.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // LearningSessionState 构造器会读取 UserPreferences，给它一个可用的内存 mock。
    SharedPreferences.setMockInitialValues({});
  });

  group('LearningSessionStarter (WS-6 core contract)', () {
    test('startBookSession 将词书与选项原样委托给会话的 loadBook', () async {
      final session = _SpySession();
      final LearningSessionStarter starter = LearningSessionStarterImpl(session);
      final book = Book(id: 1, code: 'b1', name: 'Test', wordCount: 10);

      await starter.startBookSession(book, limit: 25, shuffle: false);

      expect(session.loadedBook, book);
      expect(session.loadedLimit, 25);
      expect(session.loadedShuffle, false);
    });

    test('startBookSession 省略 option 时采用会话缺省值 (limit=null, shuffle=true)', () async {
      final session = _SpySession();
      final LearningSessionStarter starter = LearningSessionStarterImpl(session);

      await starter.startBookSession(Book(id: 2, code: 'b2', name: 'B2', wordCount: 5));

      expect(session.loadedLimit, isNull);
      expect(session.loadedShuffle, true);
    });
  });
}

/// 记录 [LearningSessionState.loadBook] 调用参数，不触及真实队列/进度副作用。
class _SpySession extends LearningSessionState {
  _SpySession()
    : super(
        queuePort: _MockQueuePort(),
        progressPort: _MockProgressPort(),
        reviewSchedulePort: _MockReviewScheduleWriterPort(),
        choicePort: _MockChoicePort(),
      );

  Book? loadedBook;
  int? loadedLimit;
  bool loadedShuffle = true;

  @override
  Future<void> loadBook(Book book, {int? limit, bool shuffle = true}) async {
    loadedBook = book;
    loadedLimit = limit;
    loadedShuffle = shuffle;
    // 不透传 super，避免真实副作用。
  }
}

class _MockQueuePort implements LearningQueuePort {
  @override
  Future<List<Word>> loadBook(Book book, {int? limit, required bool shuffle}) async => const [];

  @override
  Future<List<Word>> loadFavoriteWords({required List<Word> currentQueue}) async => const [];
}

class _MockProgressPort implements LearningProgressPort {
  @override
  Future<LearningProgress?> load() async => null;

  @override
  Future<void> save({required Book currentBook, required int currentIndex, required List<Word> queue}) async {}
}

class _MockReviewScheduleWriterPort implements ReviewScheduleWriterPort {
  @override
  Future<void> rateWord({required String word, required FsrsRating rating}) async {}

  @override
  Future<void> forget(String word) async {}
}

class _MockChoicePort implements ChoiceGeneratorPort {
  @override
  List<ChoiceCandidate> generate({
    required ChoiceCandidate correct,
    required Iterable<ChoiceCandidate> candidates,
    Random? random,
  }) => [correct];
}
