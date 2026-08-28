import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/features/learning/data/learning_progress_repository.dart';
import 'package:word_app/features/learning/data/learning_queue_repository.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/services/audio_service.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/pages/learn_page.dart';
import 'package:word_app/repositories/fav_repository.dart';
import 'package:word_app/theme/skin_system.dart';

/// 假单词源：固定返回传入的单词列表。
class _FakeWordSource implements LearningQueueWordSource {
  _FakeWordSource(this._words);
  final List<Word> _words;

  @override
  Future<List<Word>> getWordsByBook(int bookId, {required int limit, required int offset}) async {
    return List<Word>.from(_words);
  }

  @override
  Future<List<Word>> getWordsByNames(Iterable<String> words) async => const [];
}

/// 假收藏仓库（FavRepository 同步接口）。
class _FakeFavRepository implements FavRepository {
  @override
  Future<Set<String>> getFavoriteWords() async => const {};
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
  Future<List<Map<String, dynamic>>> getFavoriteSentences() async => const [];
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

class _FakeAudioService implements AudioService {
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

  testWidgets('答对后出现"查看详解"按钮（修复背单词答对后无法跳转下一个词）', (tester) async {
    final schedule = ReviewScheduleRepository();
    await schedule.initialize();
    final session = LearningSessionState(
      queueRepository: LearningQueueRepository(
        wordSource: _FakeWordSource([
          Word(id: 1, word: 'first', interpret: '第一释义'),
          Word(id: 2, word: 'second', interpret: '第二释义'),
          Word(id: 3, word: 'third', interpret: '第三释义'),
          Word(id: 4, word: 'fourth', interpret: '第四释义'),
        ]),
        favRepository: _FakeFavRepository(),
      ),
      progressRepository: LearningProgressRepository(),
      reviewSchedule: schedule,
    );
    await session.loadBook(_testBook, shuffle: false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LearningSessionState>.value(value: session),
          ChangeNotifierProvider<AudioPlaybackState>(
            create: (_) => AudioPlaybackState(audioService: _FakeAudioService()),
          ),
        ],
        // 把 Provider 放在 MaterialApp 之上，使 push 出来的 WordDetailPage 路由也能访问。
        child: MaterialApp(
          home: SkinProvider(
            skin: SkinSystem(),
            child: const LearnPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 学习页面首屏：当前词 first，词义提示/选项为 "第一释义"。
    expect(find.text('查看详解'), findsNothing);

    // 点击正确选项："第一释义"（当前词 first 的释义）。
    final choiceFinder = find.text('第一释义');
    expect(choiceFinder, findsWidgets);
    await tester.tap(choiceFinder.last);
    await tester.pumpAndSettle();

    // 修复点：出现"查看详解"按钮（此前从未实现，导致答对后无法跳转下一个词）。
    expect(find.text('查看详解'), findsOneWidget);

    // "查看详解"文本位于一个 ElevatedButton 内部（证明它是真实可点的按钮）。
    expect(
      find.ancestor(of: find.text('查看详解'), matching: find.byType(ElevatedButton)),
      findsOneWidget,
    );
  });
}

final _testBook = Book(id: 1, code: 'TEST', name: '测试', wordCount: 2);
