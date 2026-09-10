import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/audio/audio_service.dart';
import 'package:word_app/features/learning/application/learning_favorites_store.dart';
import 'package:word_app/features/learning/application/learning_session_reader.dart';
import 'package:word_app/features/learning/application/new_words_reader.dart';
import 'package:word_app/features/learning/presentation/learning_queue_word_lists_state.dart';
import 'package:word_app/features/learning/presentation/personal_stereo_page.dart';
import 'package:word_app/features/learning/presentation/play_order_page.dart';
import 'package:word_app/features/learning/presentation/review_queue_state.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/theme/skin_system.dart';

class _FakeAudioService implements AudioService {
  final played = <String>[];

  @override
  Future<void> playWordAudio(String word, {String accent = 'us', String? audioUrl}) async {
    played.add(word);
  }

  @override
  Future<void> playFromUrl(String url) async {}

  @override
  Future<void> stop() async {}

  @override
  bool get isPlaying => false;

  @override
  void dispose() {}
}

class _FakeNewWordsReader implements NewWordsReader {
  @override
  Future<List<Word>> loadWords({int? limit, int? offset}) async => [_word('apple'), _word('banana')];
}

class _FakeFavoritesStore extends LearningFavoritesStore {
  @override
  Set<String> get favoriteWords => const {};

  @override
  int get favoriteCount => 0;

  @override
  bool get isLoading => false;

  @override
  bool isFavorite(String word) => false;

  @override
  Future<void> refresh() async {}

  @override
  Future<bool> toggle(String word) async => false;

  @override
  Future<List<Word>> loadFavoriteWords({required Iterable<Word> currentQueue}) async => const [];
}

class _FakeSessionReader implements LearningSessionReader {
  @override
  Book? get currentBook => null;

  @override
  Word? get currentWord => null;

  @override
  List<Word> get queue => const [];

  @override
  int get total => 0;

  @override
  int get learnedNum => 0;
}

Word _word(String w) => Word(
  id: w.hashCode,
  word: w,
  mainWord: w,
  interpret: 'n. 测试词',
  ukPron: '',
  usPron: '',
  phrase: '',
  example: '',
  confuse: '',
);

/// REG-STEREO-001：随身听词源入口与播放契约。
///
/// 重设计为磁带机隐喻后不得丢失：
/// 1. 空态引导（随身听模式 + 选择词源提示）；
/// 2. 四个词源入口 + 播放顺序入口；
/// 3. 有词词源点击即播（显示当前词/进度/暂停钮，音频真正发声）；
/// 4. 空词源弹 SnackBar 提示。
void main() {
  late _FakeAudioService audio;

  Widget harness() {
    return MultiProvider(
      providers: [
        Provider<AudioService>.value(value: audio),
        ChangeNotifierProvider<LearningQueueWordListsState>.value(value: LearningQueueWordListsState()),
        ChangeNotifierProvider<ReviewQueueState>.value(value: ReviewQueueState()),
        Provider<NewWordsReader>.value(value: _FakeNewWordsReader()),
        ChangeNotifierProvider<LearningFavoritesStore>.value(value: _FakeFavoritesStore()),
        Provider<LearningSessionReader>.value(value: _FakeSessionReader()),
      ],
      child: MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('哑页')),
            body: Text('ROUTE:${settings.name}'),
          ),
        ),
        home: SkinProvider(skin: SkinSystem(), child: const PersonalStereoPage()),
      ),
    );
  }

  setUp(() => audio = _FakeAudioService());

  testWidgets('空态：磁带静止 + 词源入口完整', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('随身听模式'), findsOneWidget);
    expect(find.text('选择下方词源开始播放'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget); // 未播放：播放钮

    expect(find.text('选择词源'), findsOneWidget);
    for (final t in ['今日已学单词', '复习中单词', '生词本', '收藏单词', '播放顺序']) {
      expect(find.text(t), findsOneWidget, reason: '词源入口丢失：$t');
    }
  });

  testWidgets('点击有词词源立即连播：当前词/进度/暂停钮/音频调用', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('生词本'));
    // 播放中磁带卷轴 repeat 动画永不 settle，只能按帧推进。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('apple'), findsOneWidget);
    expect(find.text('生词本 · 1 / 2'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(audio.played, contains('apple'));

    // 暂停后回到播放钮
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('空词源弹 SnackBar，不进入播放态', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('复习中单词')); // fake 复习队列为空
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('该词源暂无可播放的单词'), findsOneWidget);
    expect(audio.played, isEmpty);
  });

  testWidgets('播放顺序入口导航到 PlayOrderPage', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('播放顺序'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('播放顺序'));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE:${PlayOrderPage.routeName}'), findsOneWidget);
  });
}
