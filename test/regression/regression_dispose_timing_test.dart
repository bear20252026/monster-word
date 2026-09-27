// REG-AUDIT（审计 I69）：dispose 时序类崩溃修复的回归守护。
//
// A2（search_page）：输入后 300ms 防抖 Timer 在页面退出时必须取消——
//   修复前退出后 Timer 触发 _search，对已 dispose 的 State 调 setState（必崩）。
// A1（settings_page）：「每日新学」弹层的 TextEditingController 必须
//   await 弹窗关闭后再 dispose——修复前同步 dispose，弹层首次构建即抛
//   "TextEditingController was used after being disposed"。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/application/today_progress_store.dart';
import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/learning/application/favorites_port.dart';
import 'package:word_app/features/learning/application/learning_favorites_store.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/features/learning/presentation/learning_favorites_state.dart';
import 'package:word_app/features/search/application/example_reader.dart';
import 'package:word_app/features/search/application/search_history_store.dart';
import 'package:word_app/features/search/application/word_search_reader.dart';
import 'package:word_app/features/search/data/example_parser_adapter.dart';
import 'package:word_app/features/search/presentation/search_page.dart';
import 'package:word_app/features/settings/data/learning_preferences_repository.dart';
import 'package:word_app/features/settings/presentation/learning_preferences_state.dart';
import 'package:word_app/features/settings/presentation/settings_page.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/theme/skin_system.dart';

import '../helpers/fakes.dart';

class _MockWordSearchReader implements WordSearchReader {
  @override
  Future<List<Word>> search(String query, {int? limit}) async => [];
}

class _MockHistoryStore implements SearchHistoryStore {
  @override
  List<String> read() => [];
  @override
  Future<void> add(String word) async {}
  @override
  Future<void> clear() async {}
}

class _MockFavoritesPort implements FavoritesPort {
  @override
  Future<Set<String>> getFavoriteWords() async => {};
  @override
  Future<void> toggleFavorite(String word) async {}
  @override
  bool isFavorite(String word) => false;
}

class _MockQueuePort implements LearningQueuePort {
  @override
  Future<List<Word>> loadBook(Book book, {int? limit, required bool shuffle}) async => [];
  @override
  Future<List<Word>> loadFavoriteWords({required List<Word> currentQueue}) async => [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('REG-AUDIT A2: 搜索页退出时取消防抖 Timer（不再 setState after dispose）', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WordSearchReader>(create: (_) => _MockWordSearchReader()),
          Provider<SearchHistoryStore>(create: (_) => _MockHistoryStore()),
          Provider<ExampleReader>(create: (_) => const ExampleParserAdapter()),
          ChangeNotifierProvider<LearningFavoritesState>(
            create: (_) => LearningFavoritesState(favoritesPort: _MockFavoritesPort(), queuePort: _MockQueuePort()),
          ),
          ListenableProxyProvider<LearningFavoritesState, LearningFavoritesStore>(update: (_, state, _) => state),
          ChangeNotifierProvider<AudioPlaybackState>(
            create: (_) => AudioPlaybackState(audioService: NoopAudioService()),
          ),
        ],
        child: const MaterialApp(home: SearchPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // 输入触发 300ms 防抖，随后立即退出页面——Timer 必须随 dispose 取消。
    await tester.enterText(find.byType(TextField).first, 'apple');
    await tester.pump(const Duration(milliseconds: 50));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pump(const Duration(milliseconds: 500)); // 越过防抖期限

    // 修复前：Timer 触发 _search → setState after dispose → 本测试红。
    expect(tester.takeException(), isNull);
  });

  testWidgets('REG-AUDIT A1: 每日新学弹层存活期间控制器可用、关闭后正常释放', (tester) async {
    // 偏好底层 SP 需就绪（弹层内 setGoal 会真实写持久化）
    await AppPreferences().init();
    await UserPreferences().init();

    final repo = LearningPreferencesRepository();
    final prefsState = LearningPreferencesState(reader: repo, writer: repo);
    await prefsState.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LearningPreferencesState>.value(value: prefsState),
          ChangeNotifierProvider<TodayProgressStore>(create: (_) => TodayProgressStore()),
        ],
        child: SkinProvider(
          skin: SkinSystem(),
          child: const MaterialApp(home: Scaffold(body: SettingsPage())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 打开「每日新学」弹层：修复前控制器在弹窗关闭前就被 dispose，
    // 弹层首次构建即抛 "used after being disposed"。
    await tester.scrollUntilVisible(find.text('每日新学'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('每日新学'));
    await tester.pumpAndSettle();

    // 弹层存活期间输入框真实可用（控制器未提前释放）
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '42');
    expect(find.text('42'), findsOneWidget);

    // 关闭弹层（点屏障），await 后才 dispose——关闭过程不抛异常
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
