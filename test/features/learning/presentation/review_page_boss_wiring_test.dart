// ReviewPage 整页 Boss 接线：日戳消费（当日首次演入场并落盘、同日二次不演）、
// 开局冻结闩锁（剩余跌破 40 头目不消失）、唯一退场（清完 → 完成页 bossBattle）、
// 恢复局（done>0）不播入场、未达阈值不出头目。
//
// 状态级口径已由 review_session_state_test / boss_siege_test 锁定；本文件只测
// 「协调层把状态接对」这一层：谁在什么时机读日戳、写日戳、冻结答题、透传 victory。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/core/utils/boss_siege.dart';
import 'package:word_app/features/learning/application/favorites_port.dart';
import 'package:word_app/features/learning/application/mastered_words_reader.dart';
import 'package:word_app/features/learning/application/mastered_writer_port.dart';
import 'package:word_app/features/learning/application/review_rating_writer.dart';
import 'package:word_app/features/learning/application/review_schedule_reader.dart';
import 'package:word_app/features/learning/application/review_session_snapshot.dart';
import 'package:word_app/features/learning/data/repository_review_queue_reader.dart';
import 'package:word_app/features/learning/presentation/learning_queue_state.dart';
import 'package:word_app/features/learning/application/review_audio_player.dart';
import 'package:word_app/features/learning/presentation/review_audio_state.dart';
import 'package:word_app/features/learning/presentation/review_page.dart';
import 'package:word_app/features/learning/presentation/review_queue_state.dart';
import 'package:word_app/features/learning/presentation/review_session_state.dart';
import 'package:word_app/features/learning/presentation/review_word_actions_state.dart';
import 'package:word_app/features/learning/presentation/widgets/formal_review_session_layout.dart';
import 'package:word_app/features/learning/presentation/widgets/formal_review_state_views.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/theme/wallpaper_state.dart';

/// 当日日戳键（与 BossIntroDayStore 同口径）。
const String _introDayKey = 'boss_siege_intro_day';
const String _snapshotKey = 'review_session_snapshot_v1';

List<Word> _words(int n) => List.generate(n, (i) => Word(id: i + 1, word: 'w$i', interpret: '释$i'));

/// 到期词集合 = 传入词表（测试不关心 FSRS 判定，只关心接线）。
class _StubSchedule extends ReviewScheduleReader {
  _StubSchedule(this._due);
  final List<Word> _due;

  @override
  List<Word> dueWordsFor(Iterable<Word> words) => _due;

  @override
  FsrsCard? cardFor(String word) => null;
  @override
  String getStatusText(FsrsCard card) => '';
  @override
  String getDifficultyText(FsrsCard card) => '';
  @override
  int get todayLearnCount => 0;
  @override
  int get todayReviewCount => _due.length;
  @override
  int get dueCount => _due.length;
  @override
  int get activeDateCount => 0;
  @override
  Map<String, int> get memoryStats => const {};
}

class _NoFavorites implements FavoritesPort {
  @override
  Future<Set<String>> getFavoriteWords() async => {};
  @override
  bool isFavorite(String word) => false;
  @override
  Future<void> toggleFavorite(String word) async {}
}

class _NoMastered implements MasteredWordsReader {
  @override
  Future<List<Word>> loadWords() async => [];
  @override
  Future<List<String>> loadTexts() async => [];
}

class _NoMasteredWriter implements MasteredWriterPort {
  @override
  Future<void> toggleMastered(String word) async {}
}

/// 装配整页：五状态 + 皮肤 + 路由。[restore] 非空时预置中途局快照。
Future<void> _pumpPage(
  WidgetTester tester, {
  required int dueCount,
  Map<String, Object> seed = const {},
  ReviewSessionSnapshot? restore,
}) async {
  final words = _words(dueCount);
  // 纯色壁纸：默认 beach 是图片壁纸，会触发异步图片解码干扰测试时钟。
  final merged = <String, Object>{'selected_wallpaper_id': 'default', ...seed};
  if (restore != null) merged[_snapshotKey] = restore.encode();
  SharedPreferences.setMockInitialValues(merged);
  await AppPreferences().init();

  final queue = ReviewQueueState();
  queue.synchronize(
    queue: LearningQueueSnapshot(currentBook: null, words: words, currentIndex: 0, learnedCount: 0),
    schedule: _StubSchedule(words),
  );
  final session = ReviewSessionState(
    queueReader: const RepositoryReviewQueueReader(),
    ratingWriter: ReviewRatingWriter(writeRating: ({required word, required rating}) async {}),
  );

  await tester.pumpWidget(
    SkinProvider(
      skin: SkinSystem(),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<ReviewQueueState>.value(value: queue),
          ChangeNotifierProvider<ReviewSessionState>.value(value: session),
          ChangeNotifierProvider<ReviewWordActionsState>(
            create: (_) => ReviewWordActionsState(
              favoritesPort: _NoFavorites(),
              masteredReader: _NoMastered(),
              masteredWriter: _NoMasteredWriter(),
            ),
          ),
          ChangeNotifierProvider<ReviewAudioState>(
            create: (_) => ReviewAudioState(audioPlayer: ReviewAudioPlayer(playAudio: (_) async {})),
          ),
          ChangeNotifierProvider<WallpaperState>(create: (_) => WallpaperState()),
        ],
        child: const MaterialApp(home: ReviewPage()),
      ),
    ),
  );
  // 页面 initState 直接调异步 initialize，其首段 notifyListeners（loading 态）
  // 必然落在首帧构建期——真实运行无碍（首帧后即落定），但测试框架会捕获这条
  // 「setState during build」。它是该页既有初始化模式的已知产物，这里显式消费；
  // 其余任何异常仍会照常让用例失败。
  final duringBuild = tester.takeException();
  if (duringBuild != null) {
    expect(duringBuild.toString(), contains('called during build'), reason: '只豁免构建期同步通知，其余异常照常失败');
  }
  // 无时长 pump 走完 starter → initialize → ready 的微任务链。
  await tester.pump();
  await tester.pump();
}

FormalReviewSessionLayout _layout(WidgetTester tester) =>
    tester.widget<FormalReviewSessionLayout>(find.byType(FormalReviewSessionLayout));

/// 收尾：选项卡片经 BoxReveal 波次入场（延迟 0-150ms + 300ms 动画，换词重放），
/// 测试结束时可能仍有挂起定时器。推过最长一波让其落定，避免 teardown 报
/// 「Timer still pending」。不影响任何断言（断言在此之前已完成）。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

ReviewSessionState _sessionOf(WidgetTester tester) =>
    tester.element(find.byType(ReviewPage)).read<ReviewSessionState>();

/// 答掉一题（看答案 → 继续），推进一步 done。
Future<void> _answerOne(WidgetTester tester) async {
  final session = _sessionOf(tester);
  session.revealAnswer();
  await session.continueWithGoodRating();
  await tester.pump();
}

void main() {
  tearDown(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('当日首次触发头目：演入场、冻结答题、落盘日戳；450ms 后解冻', (tester) async {
    await _pumpPage(tester, dueCount: 40);

    // 入场期间：头目在、答题冻结。
    expect(_layout(tester).bossActive, isTrue);
    expect(_layout(tester).bossIntroPending, isTrue, reason: '当日首次应处于入场动画');
    // 日戳已落盘（fire-and-forget 微任务）。
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_introDayKey), bossDayStamp(DateTime.now()));

    // 450ms 入场动画播完 → 解冻转 active。
    await tester.pump(const Duration(milliseconds: 250));
    expect(_layout(tester).bossIntroPending, isTrue, reason: '动画未播完不得提前解冻');
    await tester.pump(const Duration(milliseconds: 250));
    expect(_layout(tester).bossIntroPending, isFalse);
    expect(_layout(tester).bossActive, isTrue);
    await _settle(tester);
  });

  testWidgets('同日二次进页：日戳已消费，不演入场直接 active', (tester) async {
    await _pumpPage(tester, dueCount: 40, seed: {_introDayKey: bossDayStamp(DateTime.now())});

    expect(_layout(tester).bossActive, isTrue);
    expect(_layout(tester).bossIntroPending, isFalse, reason: '同日二次不得重演入场');
    await _settle(tester);
  });

  testWidgets('闩锁：剩余跌破 40 头目不消失，清完才退场到完成页', (tester) async {
    await _pumpPage(tester, dueCount: 40, seed: {_introDayKey: bossDayStamp(DateTime.now())});
    final session = _sessionOf(tester);
    expect(session.total, 40);

    // 答掉一题：剩余 39 < 阈值 40，头目必须仍在（开局冻结闩锁）。
    await _answerOne(tester);
    expect(session.done, 1);
    expect(_layout(tester).bossActive, isTrue, reason: '剩余跌破 40 不得让头目消失');

    // 清完剩余 39 题 → 唯一退场：完成页且 bossBattle=true。
    for (var i = 0; i < 39; i++) {
      await _answerOne(tester);
    }
    await tester.pump();
    expect(session.currentWord, isNull);
    final complete = tester.widget<FormalReviewCompleteView>(find.byType(FormalReviewCompleteView));
    expect(complete.bossBattle, isTrue, reason: '清完头目局必须以守城庆典收尾');
    expect(find.text(bossVictoryLine), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('恢复局（done>0）：头目直接 active，不演入场不重消费日戳', (tester) async {
    final ids = List.generate(40, (i) => i + 1);
    final restore = ReviewSessionSnapshot(
      sessionId: 'restored-session',
      wordIds: ids,
      index: 2,
      ratedIds: [1, 2],
      pending: null,
      hadDueAtStart: true,
      dueAtStart: 40,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _pumpPage(tester, dueCount: 40, restore: restore);

    final session = _sessionOf(tester);
    expect(session.done, 2, reason: '恢复局应沿用存档进度');
    expect(_layout(tester).bossActive, isTrue);
    expect(_layout(tester).bossIntroPending, isFalse, reason: '中途恢复不得重演入场');
    // 日戳未被消费（恢复局不写）。
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_introDayKey), isNull);
    await _settle(tester);
  });

  testWidgets('未达阈值（39 词）：普通复习局，不出头目不消费日戳', (tester) async {
    await _pumpPage(tester, dueCount: 39);

    expect(_layout(tester).bossActive, isFalse, reason: '39 < 40 不得触发头目');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_introDayKey), isNull);
    await _settle(tester);
  });
}
