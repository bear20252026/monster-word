import 'package:flutter/material.dart';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/core/learning/learning_favorites_store.dart';
import 'package:word_app/core/learning/learning_session_starter.dart';
import 'package:word_app/core/learning/new_words_store.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/book/application/book_selection_writer.dart';
import 'package:word_app/features/book/application/book_words_reader.dart';
import 'package:word_app/features/book/presentation/book_state.dart';
import 'package:word_app/features/book/presentation/book_words_page.dart';
import 'package:word_app/features/learning/application/choice_generator_port.dart';
import 'package:word_app/features/learning/application/favorites_port.dart';
import 'package:word_app/features/learning/application/learning_progress_port.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/features/learning/application/mastered_writer_port.dart';
import 'package:word_app/features/learning/application/new_words_reader.dart';
import 'package:word_app/features/learning/application/new_words_writer_port.dart';
import 'package:word_app/features/learning/application/review_schedule_writer_port.dart';
import 'package:word_app/features/learning/presentation/learning_favorites_state.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/features/learning/presentation/learning_session_starter_impl.dart';
import 'package:word_app/features/learning/presentation/new_words_state.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/new_word_record.dart';
import 'package:word_app/engine/fsrs6_engine.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/repositories/fav_repository.dart';
import 'package:word_app/repositories/new_word_repository.dart';
import 'package:word_app/services/audio_service.dart';

import '../test_helpers/fake_learning_progress_reader.dart';

/// Spy that records [LearningSessionState.loadBook] calls for verification.
///
/// Extends the concrete [LearningSessionState] and overrides [loadBook] to
/// record arguments without executing real queue/progress side effects.
class SpyLearningSessionState extends LearningSessionState {
  SpyLearningSessionState()
      : super(
          queuePort: MockLearningQueuePort(),
          progressPort: MockLearningProgressPort(),
          reviewSchedulePort: MockReviewScheduleWriterPort(),
          choicePort: MockChoiceGeneratorPort(),
        );

  Book? loadedBook;
  int? loadedLimit;
  bool loadedShuffle = true;
  int loadBookCallCount = 0;

  @override
  Future<void> loadBook(Book book, {int? limit, bool shuffle = true}) async {
    loadBookCallCount++;
    loadedBook = book;
    loadedLimit = limit;
    loadedShuffle = shuffle;
    // Do NOT call super — avoid real queue/progress side effects in widget test.
  }
}

/// 模拟 BookCatalogReader
class MockCatalogReader implements BookCatalogReader {
  @override
  Future<List<Book>> listBooks() async => [];
  @override
  Future<Book?> findById(int bookId) async => null;
}

/// 模拟 BookSelectionWriter
class MockSelectionWriter implements BookSelectionWriter {
  @override
  Future<int> getCurrentBookId() async => 0;
  @override
  Future<Book?> getCurrentBook() async => null;
  @override
  Future<void> selectBook(int bookId) async {}
}

/// 模拟 BookWordsReader（book 端口）
class MockBookWordsReader implements BookWordsReader {
  @override
  Future<List<Word>> loadWords(int bookId, {int limit = 50, int offset = 0}) async => [];
}

/// 模拟 FavRepository
class MockFavRepository implements FavRepository {
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
  Future<bool> addFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) async => true;
  @override
  Future<bool> removeFavoriteSentence(int wordId, String sentenceId) async => true;
  @override
  Future<bool> toggleFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) async => true;
  @override
  Future<bool> isFavoriteSentence(int wordId, String sentenceId) async => false;
  @override
  int get favoriteSentenceCount => 0;
}

/// 模拟 NewWordRepository
class MockNewWordRepository implements NewWordRepository {
  @override
  Future<List<NewWordRecord>> getNewWords({int? limit, int? offset}) async => [];
  @override
  Future<bool> addNewWord(Word word, {String source = 'manual'}) async => true;
  @override
  Future<bool> removeNewWord(int wordId) async => true;
  @override
  Future<bool> toggleNewWord(Word word, {String source = 'manual'}) async => true;
  @override
  Future<bool> isNewWord(int wordId) async => false;
  @override
  Future<int> getNewWordCount() async => 0;
}

/// 模拟 NewWordsReader（learning 端口）
class MockNewWordsReader implements NewWordsReader {
  @override
  Future<List<Word>> loadWords({int? limit, int? offset}) async => [];
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

/// Mock LearningQueuePort for tests.
class MockLearningQueuePort implements LearningQueuePort {
  @override
  Future<List<Word>> loadFavoriteWords({required List<Word> currentQueue}) async => [];

  @override
  Future<List<Word>> loadBook(Book book, {int? limit, required bool shuffle}) async => [];
}

/// Mock LearningProgressPort for tests.
class MockLearningProgressPort implements LearningProgressPort {
  @override
  Future<LearningProgress?> load() async => null;

  @override
  Future<void> save({required Book currentBook, required int currentIndex, required List<Word> queue}) async {}
}

/// Mock ReviewScheduleWriterPort for tests.
class MockReviewScheduleWriterPort implements ReviewScheduleWriterPort {
  @override
  Future<void> rateWord({required String word, required FsrsRating rating}) async {}

  @override
  Future<void> forget(String word) async {}
}

/// Mock ChoiceGeneratorPort for tests.
class MockChoiceGeneratorPort implements ChoiceGeneratorPort {
  @override
  List<ChoiceCandidate> generate({
    required ChoiceCandidate correct,
    required Iterable<ChoiceCandidate> candidates,
    Random? random,
  }) =>
      [];
}

/// Mock FavoritesPort for tests.
class MockFavoritesPort implements FavoritesPort {
  final Set<String> _favorites = {};

  @override
  Future<Set<String>> getFavoriteWords() async => _favorites;

  @override
  Future<void> toggleFavorite(String word) async {
    if (!_favorites.add(word)) {
      _favorites.remove(word);
    }
  }

  @override
  bool isFavorite(String word) => _favorites.contains(word);
}

/// Mock MasteredWriterPort for tests.
class MockMasteredWriterPort implements MasteredWriterPort {
  @override
  Future<void> toggleMastered(String word) async {}
}

/// Mock NewWordsWriterPort for tests.
class MockNewWordsWriterPort implements NewWordsWriterPort {
  @override
  Future<bool> toggleNewWord(Word word, {String source = 'manual'}) async => true;

  @override
  Future<bool> removeNewWord(int wordId) async => true;
}

void main() {
  late Book testBook;
  late SpyLearningSessionState spySession;
  late FakeLearningProgressReader fakeProgressReader;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    testBook = Book(id: 1, code: 'cet4', name: 'Test Book', wordCount: 3);
    spySession = SpyLearningSessionState();
    fakeProgressReader = FakeLearningProgressReader(learnedCount: 1);
  });

  Widget buildTestWidget(BookState bookState) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LearningSessionState>.value(value: spySession),
        ProxyProvider<LearningSessionState, LearningSessionStarter>(
          update: (_, session, _) => LearningSessionStarterImpl(session),
        ),
        ChangeNotifierProvider<LearningFavoritesState>(
          create: (_) => LearningFavoritesState(
            favoritesPort: MockFavoritesPort(),
            queuePort: MockLearningQueuePort(),
          ),
        ),
        ListenableProxyProvider<LearningFavoritesState, LearningFavoritesStore>(
          update: (_, state, _) => state,
        ),
        ChangeNotifierProvider<NewWordsState>(
          create: (_) => NewWordsState(
            newWordsReader: MockNewWordsReader(),
            writerPort: MockNewWordsWriterPort(),
          ),
        ),
        ListenableProxyProvider<NewWordsState, NewWordsStore>(
          update: (_, state, _) => state,
        ),
        ChangeNotifierProvider<AudioPlaybackState>(
          create: (_) => AudioPlaybackState(audioService: MockAudioService()),
        ),
        ChangeNotifierProvider<BookState>.value(value: bookState),
      ],
      child: MaterialApp(
        home: BookWordsPage(book: testBook),
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('navigated')),
          );
        },
      ),
    );
  }

  group('BookWordsPage FAB (G2 开始学习)', () {
    testWidgets('renders 开始学习 FAB', (tester) async {
      final state = BookState(
        catalogReader: MockCatalogReader(),
        selectionWriter: MockSelectionWriter(),
        wordsReader: MockBookWordsReader(),
        progressReader: fakeProgressReader,
      );
      state.setWordsForTest([
        Word(id: 1, word: 'apple'),
        Word(id: 2, word: 'banana'),
      ]);

      await tester.pumpWidget(buildTestWidget(state));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('开始学习'), findsOneWidget);
    });

    testWidgets('tapping FAB calls loadBook(book, limit: 50) and navigates to /immersive_swipe',
        (tester) async {
      final state = BookState(
        catalogReader: MockCatalogReader(),
        selectionWriter: MockSelectionWriter(),
        wordsReader: MockBookWordsReader(),
        progressReader: fakeProgressReader,
      );
      state.setWordsForTest([
        Word(id: 1, word: 'apple'),
      ]);

      String? navigatedRoute;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LearningSessionState>.value(value: spySession),
            ProxyProvider<LearningSessionState, LearningSessionStarter>(
              update: (_, session, _) => LearningSessionStarterImpl(session),
            ),
            ChangeNotifierProvider<LearningFavoritesState>(
              create: (_) => LearningFavoritesState(
                favoritesPort: MockFavoritesPort(),
                queuePort: MockLearningQueuePort(),
              ),
            ),
            ListenableProxyProvider<LearningFavoritesState, LearningFavoritesStore>(
              update: (_, state, _) => state,
            ),
            ChangeNotifierProvider<NewWordsState>(
              create: (_) => NewWordsState(
                newWordsReader: MockNewWordsReader(),
                writerPort: MockNewWordsWriterPort(),
              ),
            ),
            ListenableProxyProvider<NewWordsState, NewWordsStore>(
              update: (_, state, _) => state,
            ),
            ChangeNotifierProvider<AudioPlaybackState>(
              create: (_) => AudioPlaybackState(audioService: MockAudioService()),
            ),
            ChangeNotifierProvider<BookState>.value(value: state),
          ],
          child: MaterialApp(
            home: BookWordsPage(book: testBook),
            onGenerateRoute: (settings) {
              navigatedRoute = settings.name;
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('navigated')),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the FAB.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify loadBook was called with correct arguments.
      expect(spySession.loadBookCallCount, 1);
      expect(spySession.loadedBook, testBook);
      expect(spySession.loadedLimit, 50);

      // Verify navigation to /immersive_swipe.
      expect(navigatedRoute, '/immersive_swipe');
    });
  });
}
