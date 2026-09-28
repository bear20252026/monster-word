// 设置页 widget 测试：全量渲染 + 分组字段级更新（审计 I24 / 测试补齐批次 3）。
//
// 覆盖 settings_page.dart 的 Selector 订阅改造：
// 每组只订阅自己的字段，断言「改 A 组字段后 B 组值不变、A 组 UI 即时刷新」。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/application/today_progress_store.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/settings/data/learning_preferences_repository.dart';
import 'package:word_app/features/settings/presentation/learning_preferences_state.dart';
import 'package:word_app/features/settings/presentation/settings_page.dart';
import 'package:word_app/theme/skin_system.dart';

Future<LearningPreferencesState> _readyPrefs() async {
  final repo = LearningPreferencesRepository();
  final state = LearningPreferencesState(reader: repo, writer: repo);
  await state.initialize();
  return state;
}

Future<void> _pump(WidgetTester tester, LearningPreferencesState prefs, TodayProgressStore progress) async {
  // 放大视口：ListView 惰性构建会让屏幕外设置项不在 widget 树中
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LearningPreferencesState>.value(value: prefs),
        ChangeNotifierProvider<TodayProgressStore>.value(value: progress),
      ],
      child: MaterialApp(
        routes: {RouteNames.designLanguage: (_) => const Scaffold(body: Text('dest'))},
        home: SkinProvider(skin: SkinSystem(), child: const SettingsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('设置页渲染全部 12 个设置项', (tester) async {
    final prefs = await _readyPrefs();
    await _pump(tester, prefs, TodayProgressStore());

    const titles = ['学习提醒', '单词发音类型', '自动发音', '风格', '拼写', '每日新学', '学习节奏', '听音选义题型', '助记顺序', '拆分助记', '混淆项辨析', '更多学习偏好'];
    for (final t in titles) {
      expect(find.text(t), findsOneWidget, reason: '缺少设置项：$t');
    }
  });

  testWidgets('发音类型默认美式', (tester) async {
    final prefs = await _readyPrefs();
    await _pump(tester, prefs, TodayProgressStore());

    expect(find.text('美式'), findsOneWidget);
  });

  testWidgets('自动发音描述随两开关组合切换（Selector 字段级刷新）', (tester) async {
    final prefs = await _readyPrefs();
    await prefs.setAutoPlayAudio(false);
    await prefs.setAutoPlayExampleAudio(false);
    await _pump(tester, prefs, TodayProgressStore());

    // 全关 → 已关闭（拼写组默认开，此文本全页唯一）
    expect(find.text('已关闭'), findsOneWidget);

    // 只开自动发音 → 单词
    await prefs.setAutoPlayAudio(true);
    await tester.pumpAndSettle();
    expect(find.text('单词'), findsOneWidget);

    // 再开例句 → 单词、词义页面例句
    await prefs.setAutoPlayExampleAudio(true);
    await tester.pumpAndSettle();
    expect(find.text('单词、词义页面例句'), findsOneWidget);
  });

  testWidgets('拼写描述随两开关组合切换', (tester) async {
    final prefs = await _readyPrefs();
    await prefs.setSpellRightSwipe(false);
    await prefs.setSpellReviewTip(false);
    await _pump(tester, prefs, TodayProgressStore());

    // 全关 → 已关闭（自动发音组默认开，此文本全页唯一）
    expect(find.text('已关闭'), findsOneWidget);

    await prefs.setSpellRightSwipe(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('右滑随手拼'), findsOneWidget);

    await prefs.setSpellReviewTip(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('复习拼写提示'), findsOneWidget);
  });

  testWidgets('学习节奏 Selector 刷新数值', (tester) async {
    final prefs = await _readyPrefs();
    await _pump(tester, prefs, TodayProgressStore());

    expect(find.text('10 词/小结'), findsOneWidget);

    await prefs.setLearnPace(15);
    await tester.pumpAndSettle();
    expect(find.text('15 词/小结'), findsOneWidget);
  });

  testWidgets('每日新学 Selector 订阅 TodayProgressStore.goal', (tester) async {
    // setGoal 走 UserPreferences（BaseSharedPreferences），写入前需显式 init
    await UserPreferences().init();
    final prefs = await _readyPrefs();
    final progress = TodayProgressStore();
    await progress.setGoal(20);
    await _pump(tester, prefs, progress);

    expect(find.text('20 词'), findsOneWidget);
  });

  testWidgets('点听音选义开关：state 翻转且行内 Switch 同步', (tester) async {
    final prefs = await _readyPrefs();
    await _pump(tester, prefs, TodayProgressStore());

    expect(prefs.audioMeaningQuestion, isTrue);
    expect(find.byType(Switch), findsNWidgets(3)); // 听音选义 / 拆分助记 / 混淆项辨析

    await tester.tap(find.byType(Switch).at(0));
    await tester.pumpAndSettle();

    expect(prefs.audioMeaningQuestion, isFalse);
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches[0].value, isFalse);
    expect(switches[1].value, isTrue); // 其他开关不受影响
    expect(switches[2].value, isTrue);
  });
}
