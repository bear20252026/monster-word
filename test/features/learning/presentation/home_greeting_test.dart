// 测试：G1r 首页接线 — 问候怪兽、达标金环、签到火苗呼吸。
//
// 装配惯例抄 review_dialog_test（MultiProvider + SharedPreferences mock +
// AppPreferences().init/UserPreferences().init）；home 含无限循环动画
// （怪兽呼吸 bob / 火苗呼吸），全程禁用 pumpAndSettle，改用定量 pump。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/application/today_progress_store.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/checkin/domain/checkin_status.dart';
import 'package:word_app/features/learning/presentation/home_screen.dart';
import 'package:word_app/features/learning/presentation/learning_statistics_state.dart';
import 'package:word_app/tokens/star_gold.dart';
import 'package:word_app/widgets/confetti.dart';
import 'package:word_app/widgets/monster_icon.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences().init();
    await UserPreferences().init();
  });

  // 装配 HomeScreen：仅注入 build 期真实消费的三个对象；
  // onGenerateRoute 提供命名路由占位页（断言 pushNamed 到达 /my_space）。
  Future<TodayProgressStore> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600); // 竖屏口径，避免默认 800x600 走横屏布局
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = TodayProgressStore();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TodayProgressStore>.value(value: store),
          Provider<CheckinStatusReader>.value(value: _StubCheckinReader()),
          ChangeNotifierProvider<LearningStatisticsState>.value(value: LearningStatisticsState()),
        ],
        child: MaterialApp(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: Center(child: Text('page:${settings.name}'))),
          ),
          home: const HomeScreen(),
        ),
      ),
    );
    // 入场动画（最长约 940ms）走完；home 有无限循环动画，禁用 pumpAndSettle
    await tester.pump(const Duration(milliseconds: 1000));
    return store;
  }

  CustomPaint ringPaint(WidgetTester tester) => tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter != null && w.painter!.runtimeType.toString() == '_RingPainter',
    ),
  );

  testWidgets('问候语左侧有怪兽：MonsterIcon 存在，点击张嘴冒泡并跳转我的空间', (tester) async {
    await pumpHome(tester);
    expect(find.byType(MonsterIcon), findsOneWidget);

    await tester.tap(find.byType(MonsterIcon));
    await tester.pump(const Duration(milliseconds: 300)); // 张嘴 0.3s + 气泡淡入 180ms

    // 「咕噜~」气泡淡入至可见
    final bubble = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.text('咕噜~'), matching: find.byType(AnimatedOpacity)),
    );
    expect(bubble.opacity, 1.0);

    await tester.pump(const Duration(milliseconds: 600)); // 800ms 问候节拍走完 → pushNamed
    await tester.pump(); // 推入的 mySpace 占位页需要额外一帧完成构建
    expect(find.text('page:/my_space'), findsOneWidget);

    // 把 _settleGurgle 的 1600ms 延时跑完（否则测试结束时留下 pending timer）
    await tester.pump(const Duration(milliseconds: 2000));
    // pushNamed 后首页在不透明路由下方变 offstage，finder 需包含 offstage 子树。
    final bubbleAfter = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('咕噜~', skipOffstage: false),
        matching: find.byType(AnimatedOpacity, skipOffstage: false),
      ),
    );
    expect(bubbleAfter.opacity, 0.0); // 气泡收敛，状态复原
  });

  testWidgets('今日达标（learned≥goal）：进度环变金色并挂金色 confetti', (tester) async {
    final store = await pumpHome(tester);

    // 未达标：文案与环色为主题 accent（非金）
    expect(find.text('还差 10 个单词'), findsOneWidget);
    expect((ringPaint(tester).painter! as dynamic).progressColor, isNot(StarGold.gold));

    // 写入今日已学 ≥ 目标并通知（done 沿触发）
    await store.setGoal(10);
    await AppPreferences().setTodayLearned(12, date: _today());
    store.sync(due: 0);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('今日目标已完成'), findsOneWidget);
    expect((ringPaint(tester).painter! as dynamic).progressColor, StarGold.gold);
    final confetti = tester.widget<ConfettiOverlay>(find.byType(ConfettiOverlay));
    expect(confetti.particleCount, 30);
    expect(confetti.colors, [StarGold.gold]);
  });

  testWidgets('未签到火苗呼吸：alpha 在 o40~o90 间随时间变化', (tester) async {
    await pumpHome(tester); // stub 未签到
    final flame = find.byIcon(Icons.local_fire_department_rounded);
    expect(flame, findsOneWidget);

    final c1 = tester.widget<Icon>(flame).color!;
    expect(c1.a, inInclusiveRange(0.40, 0.90));

    await tester.pump(const Duration(milliseconds: 300));
    final c2 = tester.widget<Icon>(flame).color!;
    expect(c2.a, inInclusiveRange(0.40, 0.90));
    expect(c1, isNot(c2)); // 呼吸在动
  });
}

/// 测试替身：CheckinStatusReader（未签到口径）。
class _StubCheckinReader implements CheckinStatusReader {
  @override
  Future<CheckinStatus> getStatus() async => const CheckinStatus.empty();

  @override
  Future<Set<String>> getCheckinDates() async => const <String>{};

  @override
  Future<int> getStreakDays() async => 0;

  @override
  Future<bool> hasCheckedInToday() async => false;
}

/// 与 TodayProgressStore._date 同口径的今日日期串。
String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}
