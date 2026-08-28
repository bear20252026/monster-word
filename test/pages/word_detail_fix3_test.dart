import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/features/word_browse/application/word_notes_store.dart';
import 'package:word_app/features/learning/application/review_schedule_reader.dart';
import 'package:word_app/features/learning/data/learning_progress_repository.dart';
import 'package:word_app/features/learning/data/learning_queue_repository.dart';
import 'package:word_app/features/learning/data/repository_review_schedule_reader.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/models/word_note.dart';
import 'package:word_app/pages/word_detail_page.dart';
import 'package:word_app/repositories/fav_repository.dart';
import 'package:word_app/repositories/note_repository.dart';
import 'package:word_app/services/audio_service.dart';
import 'package:word_app/theme/skin_system.dart';

// ── Stub implementations ──

class _StubFavRepo implements FavRepository {
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

class _StubNoteRepo implements NoteRepository {
  @override
  Future<List<WordNote>> getNotesByWord(int wordId) async => [];
  @override
  Future<int> addNote(int wordId, String content, {String word = ''}) async => 0;
  @override
  Future<int> insertNote(WordNote note) async => 0;
  @override
  Future<int> updateNote(WordNote note) async => 0;
  @override
  Future<int> deleteNote(int noteId) async => 0;
  @override
  Future<List<Map<String, dynamic>>> getFavorites() async => [];
  @override
  Future<int> addFavorite(int wordId) async => 0;
  @override
  Future<int> removeFavorite(int wordId) async => 0;
  @override
  Future<bool> isFavorite(int wordId) async => false;
}

class _StubNotesStore implements WordNotesStore {
  @override
  Future<List<WordNote>> listForWord(int wordId) async => [];
  @override
  Future<void> add(WordNote note) async {}
  @override
  Future<void> update(WordNote note) async {}
  @override
  Future<void> deleteById(int noteId) async {}
}

class _StubAudioService implements AudioService {
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

class _StubQueueRepo implements LearningQueueRepository {
  @override
  Future<List<Word>> loadBook(Book book, {required int limit, bool shuffle = true}) async => const [];
  @override
  Future<List<Word>> loadFavoriteWords({required Iterable<Word> currentQueue}) async => const [];
  @override
  Future<List<Word>> loadWordsByBook(int bookId) async => const [];
}

class _StubProgressRepo implements LearningProgressRepository {
  @override
  Future<void> save({required Book? currentBook, required int currentIndex, required List<Word> queue}) async {}
  @override
  Future<LearningProgressSnapshot?> load() async => null;
}

class _StubReviewScheduleRepo extends ReviewScheduleRepository {}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// 构建测试用 Widget，通过 onGenerateRoute 建立真实 ModalRoute。
  /// [routeArguments] 为路由参数，模拟 settings.arguments。
  Widget buildPageWithArgs(Object? routeArguments) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AudioPlaybackState>(
          create: (_) => AudioPlaybackState(audioService: _StubAudioService()),
        ),
        ChangeNotifierProvider<LearningSessionState>(
          create: (_) => LearningSessionState(
            queueRepository: _StubQueueRepo(),
            progressRepository: _StubProgressRepo(),
            reviewSchedule: _StubReviewScheduleRepo(),
          ),
        ),
        Provider<FavRepository>.value(value: _StubFavRepo()),
        Provider<NoteRepository>.value(value: _StubNoteRepo()),
        Provider<WordNotesStore>.value(value: _StubNotesStore()),
        ChangeNotifierProvider<ReviewScheduleReader>(
          create: (_) => RepositoryReviewScheduleReader(
            repository: _StubReviewScheduleRepo(),
          ),
        ),
        ChangeNotifierProvider<SkinSystem>(create: (_) => SkinSystem()),
      ],
      child: MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: RouteSettings(arguments: routeArguments),
          builder: (_) => const WordDetailPage(),
        ),
      ),
    );
  }

  group('XP-FIX-3: 深链无词提示', () {
    testWidgets('无参数深链时显示错误页面 "未找到单词"', (tester) async {
      // 传入非 Word 类型参数 → _resolveTargetWord 返回 null → 错误页面
      await tester.pumpWidget(buildPageWithArgs('invalid'));
      await tester.pumpAndSettle();

      expect(find.text('未找到单词'), findsOneWidget);
      expect(find.text('可能因参数缺失或数据异常'), findsOneWidget);
    });

    testWidgets('无参数深链时显示 "返回上一页" 按钮', (tester) async {
      await tester.pumpWidget(buildPageWithArgs(null));
      await tester.pumpAndSettle();

      // 旧版 goHome 按钮不应存在
      expect(find.text('返回首页'), findsNothing);
      // 新版 safePop 按钮应存在
      expect(find.text('返回上一页'), findsOneWidget);
    });

    testWidgets('正常传入 Word 参数时显示单词详情', (tester) async {
      final word = Word(
        id: 1,
        word: 'hello',
        usPron: 'həˈloʊ',
        ukPron: 'həˈləʊ',
        interpret: 'int. 你好',
        phrase: '',
        example: '',
        wordRoot: '',
      );

      await tester.pumpWidget(buildPageWithArgs(word));
      await tester.pumpAndSettle();

      // 不应出现错误页面
      expect(find.text('未找到单词'), findsNothing);
      // 应显示单词
      expect(find.text('hello'), findsOneWidget);
    });
  });

  group('XP-FIX-3: wordDetail 路由安全转换', () {
    testWidgets('从内容路由 Map 参数进入时不崩溃', (tester) async {
      // 模拟 content_routes 传入 Map 参数（深链序列化路径）
      await tester.pumpWidget(
        buildPageWithArgs(<String, dynamic>{
          'word': 'hello',
          'fromLearn': false,
        }),
      );
      await tester.pumpAndSettle();

      // Map 无法直接转 Word → 错误页面
      expect(find.text('未找到单词'), findsOneWidget);
    });
  });
}
