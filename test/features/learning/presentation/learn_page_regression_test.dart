import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/features/learning/application/choice_generator_port.dart';
import 'package:word_app/features/learning/application/favorites_port.dart';
import 'package:word_app/features/learning/application/learning_progress_port.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/features/learning/data/repository_review_schedule_writer_port.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';
import 'package:word_app/features/learning/domain/choice_generator.dart';
import 'package:word_app/features/learning/presentation/learning_favorites_state.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/presentation/learn_page.dart';
import 'package:word_app/widgets/scratch_to_reveal.dart';
import 'package:word_app/core/audio/audio_service.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart' show FsrsRating;
import 'package:word_app/theme/skin_system.dart';

/// 假音频服务。
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
      queuePort: _FakeQueuePort([
        Word(id: 1, word: 'first', interpret: '第一释义'),
        Word(id: 2, word: 'second', interpret: '第二释义'),
        Word(id: 3, word: 'third', interpret: '第三释义'),
        Word(id: 4, word: 'fourth', interpret: '第四释义'),
      ]),
      progressPort: _FakeProgressPort(),
      reviewSchedulePort: RepositoryReviewScheduleWriterPort(schedule),
      choicePort: _FakeChoicePort(),
    );
    await session.loadBook(_testBook, shuffle: false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LearningSessionState>.value(value: session),
          ChangeNotifierProvider<AudioPlaybackState>(
            create: (_) => AudioPlaybackState(audioService: _FakeAudioService()),
          ),
          // 会话顶栏（横屏同样渲染）需要收藏状态；测试补齐最小装配。
          ChangeNotifierProvider<LearningFavoritesState>(
            create: (_) =>
                LearningFavoritesState(favoritesPort: _FakeFavoritesPort(), queuePort: _FakeQueuePort(const [])),
          ),
        ],
        // 把 Provider 放在 MaterialApp 之上，使 push 出来的 WordDetailPage 路由也能访问。
        child: MaterialApp(
          home: SkinProvider(skin: SkinSystem(), child: const LearnPage()),
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
    expect(find.ancestor(of: find.text('查看详解'), matching: find.byType(ElevatedButton)), findsOneWidget);
  });

  testWidgets('REG-SCRATCH-001: 刮刮提示每词独立遮盖——第一词刮开后下一词仍需手动刮（防泄答案）', (tester) async {
    // 症状（用户实测）：第一个词的提示刮开后，后续词的提示不再需要刮，
    //   直接自动展示释义——等于把答案告诉了用户。
    // 根因：WordScratchCard 在学习页同一树位置渲染且无 key，
    //   ScratchToRevealState 无 didUpdateWidget 重置——Element 复用让
    //   _revealed=true 与旧擦除轨迹延续到后续所有词。
    // 修复：换词以 ValueKey(word.word) 强制重建 + resetToken 触发层内重置。
    final schedule = ReviewScheduleRepository();
    await schedule.initialize();
    final session = LearningSessionState(
      queuePort: _FakeQueuePort([
        Word(id: 1, word: 'first', interpret: '第一释义'),
        Word(id: 2, word: 'second', interpret: '第二释义'),
      ]),
      progressPort: _FakeProgressPort(),
      reviewSchedulePort: RepositoryReviewScheduleWriterPort(schedule),
      choicePort: _FakeChoicePort(),
    );
    await session.loadBook(_testBook, shuffle: false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LearningSessionState>.value(value: session),
          ChangeNotifierProvider<AudioPlaybackState>(
            create: (_) => AudioPlaybackState(audioService: _FakeAudioService()),
          ),
          ChangeNotifierProvider<LearningFavoritesState>(
            create: (_) =>
                LearningFavoritesState(favoritesPort: _FakeFavoritesPort(), queuePort: _FakeQueuePort(const [])),
          ),
        ],
        child: MaterialApp(
          home: SkinProvider(skin: SkinSystem(), child: const LearnPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 第一词：提示遮盖存在（touch 图标为遮盖层唯一 oracle）
    expect(find.byIcon(Icons.touch_app), findsOneWidget);

    // 刮开第一词：三行横扫产生足够网格覆盖（onPanEnd 阈值 0.4）
    final center = tester.getCenter(find.byType(ScratchToReveal));
    Future<void> scratchPass(double dy) async {
      final gesture = await tester.startGesture(center - Offset(100, dy));
      for (var i = 0; i < 28; i++) {
        await gesture.moveBy(const Offset(8, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
    }

    await scratchPass(-30);
    await scratchPass(0);
    await scratchPass(30);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.touch_app), findsNothing, reason: '第一词刮开后遮盖应消失');

    // 推进到第二词（直接评分推进队列）
    await session.rate(FsrsRating.good);
    await tester.pumpAndSettle();
    expect(session.currentWord!.word, 'second');

    // 关键回归断言：第二词的遮盖必须重新出现（修复前此断言失败=自动泄答案）
    expect(find.byIcon(Icons.touch_app), findsOneWidget, reason: '换词后提示必须重新遮盖，不得自动露出');
  });
}

final _testBook = Book(id: 1, code: 'TEST', name: '测试', wordCount: 2);

class _FakeQueuePort implements LearningQueuePort {
  _FakeQueuePort(this._words);

  final List<Word> _words;

  @override
  Future<List<Word>> loadFavoriteWords({required List<Word> currentQueue}) async => const [];

  @override
  Future<List<Word>> loadBook(Book book, {int? limit, required bool shuffle}) async {
    final queue = List<Word>.from(_words);
    if (shuffle) {
      queue.shuffle();
    }
    return (limit == null || limit >= queue.length) ? queue : queue.sublist(0, limit);
  }
}

class _FakeProgressPort implements LearningProgressPort {
  @override
  Future<LearningProgress?> load() async => null;

  @override
  Future<void> save({required Book currentBook, required int currentIndex, required List<Word> queue}) async {}
}

class _FakeFavoritesPort implements FavoritesPort {
  @override
  Future<Set<String>> getFavoriteWords() async => const {};

  @override
  Future<void> toggleFavorite(String word) async {}

  @override
  bool isFavorite(String word) => false;
}

class _FakeChoicePort implements ChoiceGeneratorPort {
  @override
  List<ChoiceCandidate> generate({
    required ChoiceCandidate correct,
    required Iterable<ChoiceCandidate> candidates,
    Random? random,
  }) {
    return ChoiceGenerator.generate(correct: correct, candidates: candidates, random: random);
  }
}
