// 怪兽小屋（个人中心）冒烟测试：房间呈现 / 抽屉面板 / 路由跳转。
//
// 注意：页面含待机呼吸 repeat 动画（_idleCtrl.repeat），pumpAndSettle 永不收敛，
// 必须用定点 pump 推时钟。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/features/account/application/account_profile_state.dart';
import 'package:word_app/features/account/application/account_profile_store.dart';
import 'package:word_app/features/account/application/message_store.dart';
import 'package:word_app/features/account/domain/account_profile.dart';
import 'package:word_app/features/learning/application/learning_statistics_reader.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/features/settings/presentation/more_settings_page.dart';
import 'package:word_app/core/utils/monster_bond_prefs.dart';
import 'package:word_app/core/utils/monster_rhythm.dart';
import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/features/settings/presentation/profile_screen.dart';
import 'package:word_app/theme/skin_system.dart';

import '../../checkin/data/fake_scare_coin_store.dart';

class _FakeProfileStore implements AccountProfileStore {
  @override
  Future<AccountProfile> load() async => const AccountProfile.empty();

  @override
  Future<void> save(AccountProfile profile) async {}
}

class _FakeStatsReader extends ChangeNotifier implements LearningStatisticsReader {
  _FakeStatsReader({this.dueCount = 0});

  @override
  final int dueCount;

  @override
  int get total => 0;
  @override
  int get learnedCount => 7;
  @override
  int get totalLearnedDays => 3;
}

Widget _wrap(FakeScareCoinStore store, {int dueCount = 0}) {
  Widget dest(String name) => KeyedSubtree(
    key: ValueKey(name),
    child: Scaffold(body: Center(child: Text('dest'))),
  );
  return MultiProvider(
    providers: [
      Provider<ScareCoinStore>.value(value: store),
      // 顶栏 MessageBadgeIcon 需要 MessageStore（widget 测试用 mock prefs 兜底）。
      ChangeNotifierProvider<MessageStore>.value(value: MessageStore()),
      ChangeNotifierProvider<LearningStatisticsReader>.value(value: _FakeStatsReader(dueCount: dueCount)),
      ChangeNotifierProvider<AccountProfileState>(
        create: (_) => AccountProfileState(profileStore: _FakeProfileStore()),
      ),
    ],
    child: MaterialApp(
      routes: {
        RouteNames.myEquip: (_) => dest('equip'),
        RouteNames.appearance: (_) => dest('appearance'),
        RouteNames.settings: (_) => dest('settings'),
        RouteNames.personalStereo: (_) => dest('stereo'),
        RouteNames.myContent: (_) => dest('content'),
        RouteNames.footMark: (_) => dest('footMark'),
        RouteNames.mySpace: (_) => dest('mySpace'),
        RouteNames.scareCoinHistory: (_) => dest('coin'),
        MoreSettingsPage.routeName: (_) => dest('more'),
        RouteNames.accountInfo: (_) => dest('account'),
      },
      home: SkinProvider(
        skin: SkinSystem(),
        child: const Scaffold(body: ProfileScreen()),
      ),
    ),
  );
}

/// 定点推时钟：覆盖 profile/balance 异步载入 + 抽屉/路由过渡动画。
Future<void> _pumpSeq(WidgetTester tester, {double settleMs = 450}) async {
  await tester.pump(); // 微任务（profile/balance load）
  await tester.pump(Duration(milliseconds: (settleMs / 2).round()));
  await tester.pump(Duration(milliseconds: (settleMs / 2).round()));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // 时间依赖免疫：小屋有昼夜节律（W4.5），全部用例 pin 到白天 10 点，
    // 夜间行为由专门用例 pin 到 23 点验证。
    MonsterRhythm.nowOverride = () => DateTime(2026, 10, 4, 10);
  });
  tearDown(MonsterRhythm.resetForTest);

  testWidgets('怪兽小屋：门牌与八件家具名牌呈现', (tester) async {
    await tester.pumpWidget(_wrap(FakeScareCoinStore()));
    await _pumpSeq(tester);

    expect(find.text('未设置昵称'), findsOneWidget);
    expect(find.text('已坚持 3 天 · 掌握 7 词'), findsOneWidget);
    expect(find.text('0'), findsWidgets); // 余额胶囊
    for (final label in ['我的装备', '外观 & 沉浸场景', '学习偏好', '随身听', '我的内容', '学习足迹', '更多设置', '尖叫币']) {
      expect(find.text(label), findsWidgets, reason: '缺名牌：$label');
    }
  });

  testWidgets('门牌回显开局命名的怪兽名（蓝图 W4「命名的仪式」最后一环）', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'monster_hatched': 1, 'monster_name': '阿咕'});
    await tester.pumpWidget(_wrap(FakeScareCoinStore()));
    await _pumpSeq(tester);

    expect(find.textContaining('怪兽 · 阿咕'), findsOneWidget);
    expect(find.textContaining('羁绊初识'), findsOneWidget, reason: '门牌回显羁绊等级（W4.5）');
  });

  testWidgets('未破壳：门牌不出怪兽名行（不把默认名冒充用户命名）', (tester) async {
    await tester.pumpWidget(_wrap(FakeScareCoinStore()));
    await _pumpSeq(tester);

    expect(find.textContaining('怪兽 · '), findsNothing);
  });

  testWidgets('怪兽小屋：点台灯出抽屉，行点击跳转学习偏好', (tester) async {
    await tester.pumpWidget(_wrap(FakeScareCoinStore()));
    await _pumpSeq(tester);

    await tester.tap(find.text('学习偏好').first);
    await _pumpSeq(tester);
    expect(find.text('每日目标 / 提醒 / 发音'), findsOneWidget);

    await tester.tap(find.text('每日目标 / 提醒 / 发音'));
    await _pumpSeq(tester, settleMs: 600);
    expect(find.byKey(const ValueKey('settings')), findsOneWidget);
  });

  testWidgets('怪兽小屋：点存钱罐抽屉含真实余额并入兑换页', (tester) async {
    final store = FakeScareCoinStore();
    await tester.pumpWidget(_wrap(store));
    await _pumpSeq(tester);

    await tester.tap(find.text('尖叫币').first);
    await _pumpSeq(tester);
    expect(find.text('当前余额 0 币'), findsOneWidget);

    await tester.tap(find.text('兑换中心'));
    await _pumpSeq(tester, settleMs: 600);
    expect(find.byKey(const ValueKey('coin')), findsOneWidget);
  });

  testWidgets('夜间 23 点：它睡着了——Zzz、闭眼、无需求气泡（W4.5）', (tester) async {
    MonsterRhythm.nowOverride = () => DateTime(2026, 10, 4, 23);
    await tester.pumpWidget(_wrap(FakeScareCoinStore(), dueCount: 25));
    await _pumpSeq(tester);

    expect(find.byKey(const ValueKey('monster-zzz')), findsOneWidget, reason: '睡着要打呼');
    final painter = tester.widget<CustomPaint>(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_RoomMonsterPainter'),
    );
    expect((painter.painter! as dynamic).blink, 1.0, reason: '夜间闭眼（复用 blink 通道）');
    expect((painter.painter! as dynamic).happy, 0.0);
    // 即使有到期词（dueCount 25），夜里也不弹需求气泡——它睡了。
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('monster-room-bubble')), findsNothing);
  });

  testWidgets('白天长按抚摸：羁绊 +1、开心眯眼、门牌升级（W4.5）', (tester) async {
    // 预置已破壳：门牌出「怪兽 · 名字 · 羁绊…」行（未破壳没有这行）。
    SharedPreferences.setMockInitialValues(<String, Object>{'monster_hatched': 1, 'monster_name': '阿咕'});
    await tester.pumpWidget(_wrap(FakeScareCoinStore()));
    await _pumpSeq(tester);

    await tester.longPress(find.byKey(const ValueKey('room-monster')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));

    expect(await MonsterBondPrefs.points(), 1, reason: '当日首次抚摸羁绊 +1');
    final painter = tester.widget<CustomPaint>(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_RoomMonsterPainter'),
    );
    expect((painter.painter! as dynamic).happy, greaterThan(0.0), reason: '抚摸开心度驱动眯眼');
    expect(find.textContaining('羁绊初识'), findsOneWidget, reason: '1 点仍为初识（熟络要 7 点）');
    // 气泡收敛定时器（4.2s）跑完，不留 pending timer。
    await tester.pump(const Duration(milliseconds: 4300));
    // 开心表情收回定时器（1.4s）。
    await tester.pump(const Duration(milliseconds: 1500));
  });

  testWidgets('同日摸到第 4 次：它烦了（性格也是活物感，W4.5）', (tester) async {
    final today = MonsterSpeech.dayKeyOf(DateTime(2026, 10, 4));
    SharedPreferences.setMockInitialValues(<String, Object>{
      'monster_bond.pet_day': today,
      'monster_bond.pet_count': 3,
      'monster_bond.points': 2,
    });
    await tester.pumpWidget(_wrap(FakeScareCoinStore()));
    await _pumpSeq(tester);

    await tester.longPress(find.byKey(const ValueKey('room-monster')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));

    expect(await MonsterBondPrefs.points(), 2, reason: '同日不再 +1');
    expect(find.byKey(const ValueKey('monster-room-bubble')), findsOneWidget, reason: '摸烦了要有台词');
    await tester.pump(const Duration(milliseconds: 4300));
    await tester.pump(const Duration(milliseconds: 1500));
  });

  testWidgets('白天进屋：到期词 ≥20 弹复习需求气泡（W4.5「它会找你」）', (tester) async {
    await tester.pumpWidget(_wrap(FakeScareCoinStore(), dueCount: 25));
    await _pumpSeq(tester);

    expect(find.byKey(const ValueKey('monster-room-bubble')), findsOneWidget);
    final text = tester.widget<Text>(find.byKey(const ValueKey('monster-room-bubble'))).data!;
    // 气泡文案 ∈ needReview 模板渲染集（{due} 注入真实 25；无变量保底条原样）。
    final candidates = MonsterSpeech.templatesOf(SpeechSlot.needReview).map((t) => t.replaceAll('{due}', '25')).toSet();
    expect(candidates, contains(text), reason: '需求气泡必须是真实到期数渲染出的模板之一：$text');
    expect(text.contains('{'), isFalse, reason: '不留未渲染占位符');
    await tester.pump(const Duration(milliseconds: 4300));
  });
}
