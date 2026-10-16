// 空词表降级测试（DictationSessionPage / QuickSpellPage / SessionExitGuard）。
//
// ⚠️ 2026-10-16 R3-L05 修正：本文件原先**不注入 `LearningSessionState`**，
// 于是页面 initState 里的 `context.read<LearningSessionState>()` 直接抛
// `ProviderNotFoundException` —— 而当时的 `SpellingQuizController.load` 是
// `catch (_) { words = const []; }`，把这个异常**静默吞成空词表**，
// 所以断言「显示暂无待学习单词」照样通过。
//
// 也就是说：这两个用例**测的其实是「装载失败被伪装成空态」这个缺陷本身**。
// R3-L05 让失败态可区分后它们立刻红了 —— 这是守卫在起作用，不是回归。
//
// 现在改为注入一个**队列为空**的真实 `LearningSessionState`，让它们回归本意：
// 验证「真的没有待学单词」时显示空态 + 返回首页按钮。
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/application/presentation_prefs.dart';
import 'package:word_app/core/application/today_progress_store.dart';
import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/features/learning/application/choice_generator_port.dart';
import 'package:word_app/features/learning/application/learning_progress_port.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/features/learning/data/repository_review_schedule_writer_port.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';
import 'package:word_app/features/learning/presentation/dictation_session_page.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/features/learning/presentation/quick_spell_page.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/widgets/session_exit_guard.dart';
import 'package:word_app/widgets/monster_icon.dart';
import 'package:word_app/theme/skin_system.dart';

import '../../../helpers/fakes.dart';

// ── 空队列装配：让「真的没有待学单词」成为真实场景（而不是被吞掉的异常）──

class _EmptyQueuePort implements LearningQueuePort {
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
  }) => [correct];
}

/// 队列为空的会话状态（不触发任何 IO）。
LearningSessionState _emptySession() => LearningSessionState(
  queuePort: _EmptyQueuePort(),
  progressPort: _StubProgressPort(),
  reviewSchedulePort: RepositoryReviewScheduleWriterPort(ReviewScheduleRepository()),
  choicePort: _StubChoicePort(),
  todayStore: TodayProgressStore(),
  prefs: PresentationPrefs(),
);

/// 页面依赖：空队列会话 + 音频（`_DictationPrompt` 会读 AudioPlaybackState）。
Widget _wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider<LearningSessionState>(create: (_) => _emptySession()),
    ChangeNotifierProvider<AudioPlaybackState>(create: (_) => AudioPlaybackState(audioService: NoopAudioService())),
  ],
  child: SkinProvider(skin: SkinSystem(), child: child),
);

void main() {
  // ────────────────────────────────────────────────
  // DictationSessionPage: 空词表降级
  // ────────────────────────────────────────────────

  group('DictationSessionPage 空词表', () {
    testWidgets('空 words 时显示空态页 + 返回首页按钮，不白屏', (tester) async {
      await tester.pumpWidget(MaterialApp(home: _wrap(DictationSessionPage())));
      await tester.pumpAndSettle();

      expect(find.text('暂无待学习单词'), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);
      expect(find.byType(MonsterIcon), findsOneWidget);
      expect(find.text('单词加载失败，请重试'), findsNothing, reason: '队列为空是「真的没词」而非装载失败，二者必须可区分（R3-L05）');
    });

    testWidgets('空 words 点击返回首页触发 goHome 回到根路由', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('root'))),
          ),
        ),
      );

      navKey.currentState!.push(MaterialPageRoute(builder: (_) => _wrap(DictationSessionPage())));
      await tester.pumpAndSettle();

      expect(find.text('暂无待学习单词'), findsOneWidget);

      await tester.tap(find.text('返回首页'));
      await tester.pumpAndSettle();

      expect(find.text('root'), findsOneWidget);
    });
  });

  // ────────────────────────────────────────────────
  // QuickSpellPage: 空词表降级
  // ────────────────────────────────────────────────

  group('QuickSpellPage 空词表', () {
    testWidgets('空 words 时显示空态页 + 返回首页按钮，不白屏', (tester) async {
      await tester.pumpWidget(MaterialApp(home: _wrap(QuickSpellPage())));
      await tester.pumpAndSettle();

      expect(find.text('暂无待学习单词'), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);
      expect(find.byType(MonsterIcon), findsOneWidget);
      expect(find.text('单词加载失败，请重试'), findsNothing, reason: '同上：空队列 ≠ 装载失败');
    });

    testWidgets('空 words 点击返回首页触发 goHome 回到根路由', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('root'))),
          ),
        ),
      );

      navKey.currentState!.push(MaterialPageRoute(builder: (_) => _wrap(QuickSpellPage())));
      await tester.pumpAndSettle();

      expect(find.text('暂无待学习单词'), findsOneWidget);

      await tester.tap(find.text('返回首页'));
      await tester.pumpAndSettle();

      expect(find.text('root'), findsOneWidget);
    });
  });

  // ────────────────────────────────────────────────
  // SessionExitGuard: safePop 守卫
  // ────────────────────────────────────────────────

  group('SessionExitGuard', () {
    testWidgets('包裹子 widget 后系统返回弹出退出确认对话框', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('root'))),
          ),
        ),
      );

      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => SessionExitGuard(child: const Scaffold(body: Text('session'))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('session'), findsOneWidget);

      // Simulate system back via handlePopRoute
      await tester.binding.handlePopRoute();
      // Need extra pump for async dialog to appear
      await tester.pump();
      await tester.pumpAndSettle();

      // Should show exit confirmation dialog (default subject = '当前练习')
      expect(find.text('退出当前练习？'), findsOneWidget);
    });

    testWidgets('确认退出后执行 safePop 回到上一页', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('root'))),
          ),
        ),
      );

      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => SessionExitGuard(child: const Scaffold(body: Text('session'))),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger system back → shows dialog
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('退出当前练习？'), findsOneWidget);

      // Tap "暂停并保存" button
      await tester.tap(find.text('暂停并保存'));
      await tester.pumpAndSettle();

      // Should have popped back to root
      expect(find.text('root'), findsOneWidget);
    });
  });
}
