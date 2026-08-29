import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:math';

import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/core/learning/learning_session_reader.dart';
import 'package:word_app/core/learning/learning_session_starter.dart';
import 'package:word_app/features/learning/presentation/learning_session_starter_impl.dart';
import 'package:word_app/features/word_browse/application/word_notes_store.dart';
import 'package:word_app/features/learning/application/choice_generator_port.dart';
import 'package:word_app/features/learning/application/learning_progress_port.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/features/learning/application/review_schedule_reader.dart';
import 'package:word_app/features/learning/data/repository_review_schedule_reader.dart';
import 'package:word_app/features/learning/data/repository_review_schedule_writer_port.dart';
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

/// 模拟 FavRepository
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

/// 模拟 NoteRepository
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

/// 模拟 WordNotesStore
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

/// 模拟 AudioService
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// 构建测试用 WordDetailPage，通过路由参数传入 Word。
  /// 使用 MaterialApp.onGenerateRoute 建立真实的 ModalRoute，
  /// 确保 ModalRoute.of(context) 在 initState 中可用。
  Widget buildPage(Word word) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AudioPlaybackState>(
          create: (_) => AudioPlaybackState(audioService: _StubAudioService()),
        ),
        ChangeNotifierProvider<LearningSessionState>(
          create: (_) => LearningSessionState(
            queuePort: _StubQueuePort(),
            progressPort: _StubProgressPort(),
            reviewSchedulePort: RepositoryReviewScheduleWriterPort(_StubReviewScheduleRepo()),
            choicePort: _StubChoicePort(),
          ),
        ),
        ProxyProvider<LearningSessionState, LearningSessionReader>(
          update: (_, session, _) => LearningSessionStarterImpl(session),
        ),
        ProxyProvider<LearningSessionState, LearningSessionStarter>(
          update: (_, session, _) => LearningSessionStarterImpl(session),
        ),
        Provider<FavRepository>.value(value: _StubFavRepo()),
        Provider<NoteRepository>.value(value: _StubNoteRepo()),
        Provider<WordNotesStore>.value(value: _StubNotesStore()),
        ChangeNotifierProvider<ReviewScheduleReader>(
          create: (_) => RepositoryReviewScheduleReader(repository: _StubReviewScheduleRepo()),
        ),
        ChangeNotifierProvider<SkinSystem>(create: (_) => SkinSystem()),
      ],
      child: MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: RouteSettings(arguments: word),
          builder: (_) => const WordDetailPage(),
        ),
      ),
    );
  }

  group('WordDetailPage 词组/词根词缀结构化展示 (WS-5 D1)', () {
    testWidgets('有 phrase 数据时渲染出英文短语和中文', (tester) async {
      // 注意：词库 phrase JSON 字段名为 t（类型）和 p（短语列表），非 type/items
      final word = Word(
        id: 1,
        word: 'hello',
        usPron: 'həˈloʊ',
        ukPron: 'həˈləʊ',
        interpret: 'int. 你好',
        phrase:
            '[{"t":0,"p":[{"en":"say hello","cn":"打招呼","exams":"[\\"四级\\"]"},{"en":"hello world","cn":"你好世界","exams":"[]"}]}]',
        example: '',
        wordRoot: '',
      );

      await tester.pumpWidget(buildPage(word));
      await tester.pumpAndSettle();

      // 词组区块应显示
      expect(find.text('词组/搭配'), findsOneWidget);
      expect(find.text('say hello'), findsOneWidget);
      expect(find.text('打招呼'), findsOneWidget);
      expect(find.text('hello world'), findsOneWidget);
      // exams 标签
      expect(find.text('四级'), findsOneWidget);
      // 不应出现原始 JSON 字符串
      expect(find.textContaining('{"en":'), findsNothing);
    });

    testWidgets('有 wordRoot 数据时渲染词根词缀', (tester) async {
      // WordRootData.fromJson 期望格式: {"prefix":"bio","roots":["bio=生命","log=学科"],"suffix":"y"}
      final word = Word(
        id: 2,
        word: 'biology',
        usPron: '',
        ukPron: '',
        interpret: 'n. 生物学',
        phrase: '',
        example: '',
        wordRoot: '{"prefix":"bio","roots":["bio=生命","log=学科"],"suffix":"y"}',
      );

      await tester.pumpWidget(buildPage(word));
      await tester.pumpAndSettle();

      // 词根词缀区块应显示
      expect(find.text('词根词缀'), findsOneWidget);
      // 应显示词根内容（WordRootTab 在结构图和详情中均渲染）
      expect(find.text('bio=生命'), findsAtLeastNWidgets(1));
      expect(find.text('log=学科'), findsAtLeastNWidgets(1));
    });

    testWidgets('无 phrase 数据时不显示词组区块', (tester) async {
      final word = Word(
        id: 3,
        word: 'hello',
        usPron: '',
        ukPron: '',
        interpret: 'int. 你好',
        phrase: '',
        example: '',
        wordRoot: '',
      );

      await tester.pumpWidget(buildPage(word));
      await tester.pumpAndSettle();

      expect(find.text('词组/搭配'), findsNothing);
    });

    testWidgets('无 wordRoot 数据时不显示词根词缀区块', (tester) async {
      final word = Word(
        id: 4,
        word: 'hello',
        usPron: '',
        ukPron: '',
        interpret: 'int. 你好',
        phrase: '',
        example: '',
        wordRoot: '',
      );

      await tester.pumpWidget(buildPage(word));
      await tester.pumpAndSettle();

      expect(find.text('词根词缀'), findsNothing);
    });

    testWidgets('phrase 和 wordRoot 同时存在时两个区块都显示', (tester) async {
      final word = Word(
        id: 5,
        word: 'biology',
        usPron: '',
        ukPron: '',
        interpret: 'n. 生物学',
        phrase:
            '[{"t":0,"p":[{"en":"biological diversity","cn":"生物多样性","exams":"[]"}]}]',
        example: '',
        wordRoot: '{"roots":["bio=生命"]}',
      );

      await tester.pumpWidget(buildPage(word));
      await tester.pumpAndSettle();

      expect(find.text('词组/搭配'), findsOneWidget);
      expect(find.text('词根词缀'), findsOneWidget);
      expect(find.text('biological diversity'), findsOneWidget);
      expect(find.textContaining('bio'), findsAtLeastNWidgets(1));
    });
  });
}

// ── 以下为 LearningSessionState 所需的 stub ──

class _StubQueuePort implements LearningQueuePort {
  @override
  Future<List<Word>> loadBook(Book book, {int? limit, required bool shuffle}) async => const [];

  @override
  Future<List<Word>> loadFavoriteWords({required List<Word> currentQueue}) async => const [];
}

class _StubProgressPort implements LearningProgressPort {
  @override
  Future<void> save({required Book currentBook, required int currentIndex, required List<Word> queue}) async {}

  @override
  Future<LearningProgress?> load() async => null;
}

class _StubChoicePort implements ChoiceGeneratorPort {
  @override
  List<ChoiceCandidate> generate({
    required ChoiceCandidate correct,
    required Iterable<ChoiceCandidate> candidates,
    Random? random,
  }) =>
      [correct];
}

class _StubReviewScheduleRepo extends ReviewScheduleRepository {}
