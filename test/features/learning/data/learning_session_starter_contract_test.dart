import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/learning/learning_session_starter.dart';
import 'package:word_app/features/learning/data/learning_progress_repository.dart';
import 'package:word_app/features/learning/data/learning_queue_repository.dart';
import 'package:word_app/features/learning/data/learning_session_starter_impl.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/repositories/fav_repository.dart';

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
          queueRepository: LearningQueueRepository(
            wordSource: _MockWordSource(),
            favRepository: _MockFavRepository(),
          ),
          progressRepository: LearningProgressRepository(),
          reviewSchedule: ReviewScheduleRepository(),
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

class _MockWordSource implements LearningQueueWordSource {
  @override
  Future<List<Word>> getWordsByBook(int bookId, {required int limit, required int offset}) async => [];
  @override
  Future<List<Word>> getWordsByNames(Iterable<String> words) async => [];
}

class _MockFavRepository implements FavRepository {
  @override
  Future<Set<String>> getFavoriteWords() async => {};
  @override
  Future<void> addFavorite(String word) async {}
  @override
  Future<void> removeFavorite(String word) async {}
  @override
  Future<void> toggleFavorite(String word) async {}
  @override
  bool isFavorite(String word) => false;
  @override
  int get favoriteCount => 0;
  @override
  Future<List<Map<String, dynamic>>> getFavoriteSentences() async => [];
  @override
  Future<bool> addFavoriteSentence({required int wordId, required String sentenceId, required String english, required String chinese, String source = ''}) async => true;
  @override
  Future<bool> removeFavoriteSentence(int wordId, String sentenceId) async => true;
  @override
  Future<bool> toggleFavoriteSentence({required int wordId, required String sentenceId, required String english, required String chinese, String source = ''}) async => true;
  @override
  Future<bool> isFavoriteSentence(int wordId, String sentenceId) async => false;
  @override
  int get favoriteSentenceCount => 0;
}
