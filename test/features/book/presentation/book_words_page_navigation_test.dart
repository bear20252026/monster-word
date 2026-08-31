import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/book/application/book_selection_writer.dart';
import 'package:word_app/features/book/application/book_words_reader.dart';
import 'package:word_app/features/book/presentation/book_state.dart';
import 'package:word_app/features/book/presentation/book_words_page.dart';
import 'package:word_app/features/learning/application/favorites_port.dart';
import 'package:word_app/features/learning/application/new_words_reader.dart';
import 'package:word_app/features/learning/application/new_words_writer_port.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/features/learning/presentation/learning_favorites_state.dart';
import 'package:word_app/features/learning/presentation/new_words_state.dart';
import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/features/learning/application/learning_favorites_store.dart';
import 'package:word_app/features/learning/application/new_words_store.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/core/audio/audio_service.dart';

import '../test_helpers/fake_learning_progress_reader.dart';

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

/// 模拟 BookWordsReader（book 端口）——全量语义，返回测试词
class MockBookWordsReader implements BookWordsReader {
  @override
  Future<List<Word>> loadWords(int bookId) async => [Word(id: 1, word: 'apple')];
}

/// 模拟 FavoritesPort（learning 端口）
class MockFavoritesPort implements FavoritesPort {
  @override
  Future<Set<String>> getFavoriteWords() async => {};
  @override
  Future<void> toggleFavorite(String word) async {}
  @override
  bool isFavorite(String word) => false;
}

/// 模拟 LearningQueuePort（learning 端口）
class MockLearningQueuePort implements LearningQueuePort {
  @override
  Future<List<Word>> loadBook(Book book, {int? limit, required bool shuffle}) async => [];

  @override
  Future<List<Word>> loadFavoriteWords({required List<Word> currentQueue}) async => [];
}

/// 模拟 NewWordsReader（learning 端口）
class MockNewWordsReader implements NewWordsReader {
  @override
  Future<List<Word>> loadWords({int? limit, int? offset}) async => [];
}

/// 模拟 NewWordsWriterPort（learning 端口）
class MockNewWordsWriterPort implements NewWordsWriterPort {
  @override
  Future<bool> toggleNewWord(Word word, {String source = 'manual'}) async => false;

  @override
  Future<bool> removeNewWord(int wordId) async => false;
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

void main() {
  testWidgets('点击单词卡片触发导航到 WordDetailPage', (tester) async {
    final word = Word(id: 1, word: 'apple');
    final book = Book(id: 1, code: 'cet4', name: 'CET-4', wordCount: 1);

    String? navigatedRoute;
    dynamic navigatedArguments;

    // 创建预初始化的 BookState
    final bookState = BookState(
      catalogReader: MockCatalogReader(),
      selectionWriter: MockSelectionWriter(),
      wordsReader: MockBookWordsReader(),
      progressReader: FakeLearningProgressReader(learnedCount: 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          navigatedRoute = settings.name;
          navigatedArguments = settings.arguments;
          return MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('WordDetail')),
            settings: settings,
          );
        },
        home: MultiProvider(
          providers: [
            Provider<BookCatalogReader>.value(value: MockCatalogReader()),
            Provider<BookSelectionWriter>.value(value: MockSelectionWriter()),
            Provider<BookWordsReader>.value(value: MockBookWordsReader()),
            ChangeNotifierProvider<BookState>.value(value: bookState),
            ChangeNotifierProvider<LearningFavoritesState>(
              create: (_) =>
                  LearningFavoritesState(favoritesPort: MockFavoritesPort(), queuePort: MockLearningQueuePort()),
            ),
            ListenableProxyProvider<LearningFavoritesState, LearningFavoritesStore>(update: (_, state, _) => state),
            ChangeNotifierProvider<NewWordsState>(
              create: (_) => NewWordsState(newWordsReader: MockNewWordsReader(), writerPort: MockNewWordsWriterPort()),
            ),
            ListenableProxyProvider<NewWordsState, NewWordsStore>(update: (_, state, _) => state),
            ChangeNotifierProvider<AudioPlaybackState>(
              create: (_) => AudioPlaybackState(audioService: MockAudioService()),
            ),
          ],
          child: BookWordsPage(book: book),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 查找单词卡片
    final wordCardFinder = find.text('apple');
    expect(wordCardFinder, findsOneWidget);

    // 点击单词卡片
    await tester.tap(wordCardFinder);
    await tester.pumpAndSettle();

    // 验证导航
    expect(navigatedRoute, '/word_detail');
    expect((navigatedArguments as Word).word, word.word);
  });
}
