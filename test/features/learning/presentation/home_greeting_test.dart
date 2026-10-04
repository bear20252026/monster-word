// 测试：G1r 首页接线 — 问候怪兽、达标金环、签到火苗呼吸。
//
// 装配惯例抄 review_dialog_test（MultiProvider + SharedPreferences mock +
// AppPreferences().init/UserPreferences().init）；home 含无限循环动画
// （怪兽呼吸 bob / 火苗呼吸），全程禁用 pumpAndSettle，改用定量 pump。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/core/utils/monster_rhythm.dart';
import 'package:word_app/core/application/today_progress_store.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/checkin/domain/checkin_status.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/features/learning/presentation/home_screen.dart';
import 'package:word_app/features/learning/presentation/learning_statistics_state.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/tokens/star_gold.dart';
import 'package:word_app/widgets/confetti.dart';
import 'package:word_app/widgets/monster_icon.dart';

import '../../checkin/data/fake_scare_coin_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // 昼夜节律（W4.5）时间免疫：默认用例 pin 白天；夜间行为有专测 pin 23 点。
    MonsterRhythm.nowOverride = () => DateTime(2026, 10, 4, 10);
    await AppPreferences().init();
    await UserPreferences().init();
  });
  tearDown(MonsterRhythm.resetForTest);

  // 装配 HomeScreen：仅注入 build 期真实消费的对象；
  // onGenerateRoute 提供命名路由占位页（断言 pushNamed 到达 /my_space）。
  // coinStore 传 null 即「无账本语境」（余额无通道）。
  Future<TodayProgressStore> pumpHome(
    WidgetTester tester, {
    FakeScareCoinStore? coinStore,
    CheckinStatusReader reader = const _StubCheckinReader(),
  }) async {
    tester.view.physicalSize = const Size(800, 1600); // 竖屏口径，避免默认 800x600 走横屏布局
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = TodayProgressStore();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TodayProgressStore>.value(value: store),
          Provider<CheckinStatusReader>.value(value: reader),
          ChangeNotifierProvider<LearningStatisticsState>.value(value: LearningStatisticsState()),
          if (coinStore != null) Provider<ScareCoinStore>.value(value: coinStore),
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

  /// 真实数据注入后的候选文案集合：模板 ×（天数/连击/余额/形态）渲染结果。
  /// 审计 P2-1 的守卫口径——候选只能由真实变量生成，不得再写死占位值；
  /// balance 为 null 时含 {balance} 的模板整条不参与（与引擎同规则）。
  Set<String> candidatesWith({required int days, required int streak, int? balance}) {
    final stage = MonsterIcon.stageName(MonsterIcon.stageFor(days));
    return MonsterSpeech.templatesOf(SpeechSlot.dailyGreeting)
        .where((t) => balance != null || !t.contains('{balance}'))
        .map(
          (tpl) => tpl
              .replaceAll('{stage}', stage)
              .replaceAll('{days}', '$days')
              .replaceAll('{streak}', '$streak')
              .replaceAll('{balance}', '$balance'),
        )
        .toSet();
  }

  String bubbleText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('monster-greeting-bubble'))).data!;

  CustomPaint ringPaint(WidgetTester tester) => tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter != null && w.painter!.runtimeType.toString() == '_RingPainter',
    ),
  );

  testWidgets('问候语左侧有怪兽：MonsterIcon 存在，点击张嘴冒泡并跳转我的空间', (tester) async {
    final coins = FakeScareCoinStore()
      ..balanceValue = 233
      ..streakDays = 5;
    await pumpHome(
      tester,
      coinStore: coins,
      reader: _StubCheckinReader(dates: _days(12), streakDays: 5),
    );
    expect(find.byType(MonsterIcon), findsOneWidget);

    await tester.tap(find.byType(MonsterIcon));
    await tester.pump(const Duration(milliseconds: 300)); // 张嘴 0.3s + 气泡淡入 180ms

    // 气泡文案必须来自「真实数据渲染出的模板」：12 天 → 尖角形态、余额 233、连击 5。
    // 硬编码占位值（奶泡/0 枚/签到 0 天）会落进 candidates 之外而失败（审计 P2-1）。
    final candidates = candidatesWith(days: 12, streak: 5, balance: 233);
    final text = bubbleText(tester);
    expect(candidates, contains(text), reason: '气泡文案必须是真实变量渲染出的模板之一');
    expect(text, isNot(contains('0 枚尖叫币')), reason: '不得向用户报假余额');
    expect(text, isNot(contains('奶泡')), reason: '12 天已是尖角形态，不得报初生形态');
    final bubble = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.byKey(const ValueKey('monster-greeting-bubble')), matching: find.byType(AnimatedOpacity)),
    );
    expect(bubble.opacity, 1.0);

    await tester.pump(const Duration(milliseconds: 600)); // 800ms 问候节拍走完 → pushNamed
    await tester.pump(); // 推入的 mySpace 占位页需要额外一帧完成构建
    expect(find.text('page:/my_space'), findsOneWidget);

    // 把 _settleGurgle 的 1600ms 延时跑完（否则测试结束时留下 pending timer）
    await tester.pump(const Duration(milliseconds: 2000));
    // pushNamed 后首页在不透明路由下方变 offstage，finder 需包含 offstage 子树。
    // 收敛断言（offstage + 随机文案）：不再有全亮气泡层。
    final allBubbles = tester.widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity, skipOffstage: false));
    expect(allBubbles.any((w) => w.opacity >= 1.0), isFalse, reason: '跳转后气泡应收敛');
  });

  testWidgets('无账本语境：气泡不提尖叫币，也不留未渲染占位符', (tester) async {
    await pumpHome(tester); // 不注入 ScareCoinStore → 余额无通道

    await tester.tap(find.byType(MonsterIcon));
    await tester.pump(const Duration(milliseconds: 300));

    final text = bubbleText(tester);
    expect(text, isNot(contains('{')), reason: '不得留下未渲染占位符');
    expect(text, isNot(contains('尖叫币')), reason: '读不到余额就不许报余额');
    expect(candidatesWith(days: 0, streak: 0, balance: null), contains(text));

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 2000)); // 收敛 _settleGurgle
  });

  testWidgets('800ms 节拍窗内连点两下只推开一层我的空间（审计 P2-6）', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byType(MonsterIcon));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(MonsterIcon)); // 节拍窗内的第二次点击应被闸门吃掉
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();

    expect(find.text('page:/my_space'), findsOneWidget, reason: '双击不得叠两层路由');

    await tester.pump(const Duration(milliseconds: 2000)); // 跑完 _settleGurgle 的延时
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

  testWidgets('夜间 23 点点击怪兽：说睡话（不提余额/形态，W4.5）', (tester) async {
    MonsterRhythm.nowOverride = () => DateTime(2026, 10, 4, 23);
    final coins = FakeScareCoinStore()
      ..balanceValue = 233
      ..streakDays = 5;
    await pumpHome(
      tester,
      coinStore: coins,
      reader: _StubCheckinReader(dates: _days(12), streakDays: 5),
    );

    await tester.tap(find.byType(MonsterIcon));
    await tester.pump(const Duration(milliseconds: 300));

    final text = bubbleText(tester);
    final candidates = MonsterSpeech.templatesOf(SpeechSlot.sleepyGreeting)
        .map((t) => t.replaceAll('{name}', '咕噜'))
        .toSet();
    expect(candidates, contains(text), reason: '夜里点击必须得到睡话槽文案：$text');
    expect(text.contains('233'), isFalse, reason: '睡话不报余额（它都睡了）');
    expect(text.contains('尖角'), isFalse, reason: '睡话不报形态');

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('page:/my_space'), findsOneWidget, reason: '夜间点击不拦截导航');
    await tester.pump(const Duration(milliseconds: 2000));
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

  testWidgets('REG-FLAME-001: 签到后火苗 ticker 必须停（不全天 60fps 空转）', (tester) async {
    bool flameAnimating() {
      final state = tester.state(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_CheckInStrip')) as dynamic;
      return state.flameAnimatingForTest as bool;
    }

    // 未签到：呼吸在转（REG-FLAME 前置口径）。
    final reader = _FlippableCheckinReader(checkedToday: false);
    await pumpHome(tester, reader: reader);
    await tester.pump(const Duration(milliseconds: 300));
    expect(flameAnimating(), isTrue, reason: '未签到时火苗呼吸必须开着');

    // 真实 reload 触发路径：点开签到条（推聚宝日历）再返回 → _openSheet 返回后 _reload。
    // （两次 pumpHome 根组件同类型会复用 Element，_reload 不会重跑——必须走真实路径。）
    reader.checkedToday = true;
    await tester.ensureVisible(find.text('今天还没签到，别断啦'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('今天还没签到，别断啦'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    // 过渡期间路由文本可能带 offstage 标记：finder 必须带上 skipOffstage:false。
    expect(find.text('page:${RouteNames.treasureCheckIn}', skipOffstage: false), findsOneWidget, reason: '签到条应推开聚宝日历');
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(flameAnimating(), isFalse, reason: '签到后返回首页，_reload 必须 stop 火苗 ticker');
    await tester.pump(const Duration(milliseconds: 2000)); // 收敛 home 其余延时
  });
}

/// 测试替身：CheckinStatusReader（默认未签到口径）。
class _StubCheckinReader implements CheckinStatusReader {
  const _StubCheckinReader({this.dates = const <String>{}, this.streakDays = 0});

  final Set<String> dates;
  final int streakDays;

  @override
  Future<CheckinStatus> getStatus() async => const CheckinStatus.empty();

  @override
  Future<Set<String>> getCheckinDates() async => dates;

  @override
  Future<int> getStreakDays() async => streakDays;

  @override
  Future<bool> hasCheckedInToday() async => false;
}

/// 可变签到读取替身：REG-FLAME 用（签到状态在会话中途翻转）。
class _FlippableCheckinReader implements CheckinStatusReader {
  _FlippableCheckinReader({required this.checkedToday});

  bool checkedToday;

  @override
  Future<CheckinStatus> getStatus() async => const CheckinStatus.empty();

  @override
  Future<Set<String>> getCheckinDates() async => {
    for (var i = 1; i <= 12; i++) '2026-09-${i.toString().padLeft(2, '0')}',
  };

  @override
  Future<int> getStreakDays() async => 5;

  @override
  Future<bool> hasCheckedInToday() async => checkedToday;
}

/// n 个互不相同的签到日期串（累计天数即 n）。
Set<String> _days(int n) => {for (var i = 1; i <= n; i++) '2026-09-${i.toString().padLeft(2, '0')}'};

/// 与 TodayProgressStore._date 同口径的今日日期串。
String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}
