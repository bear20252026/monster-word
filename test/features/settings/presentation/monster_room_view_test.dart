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
  @override
  int get total => 0;
  @override
  int get dueCount => 0;
  @override
  int get learnedCount => 7;
  @override
  int get totalLearnedDays => 3;
}

Widget _wrap(FakeScareCoinStore store) {
  Widget dest(String name) => KeyedSubtree(
    key: ValueKey(name),
    child: Scaffold(body: Center(child: Text('dest'))),
  );
  return MultiProvider(
    providers: [
      Provider<ScareCoinStore>.value(value: store),
      // 顶栏 MessageBadgeIcon 需要 MessageStore（widget 测试用 mock prefs 兜底）。
      ChangeNotifierProvider<MessageStore>.value(value: MessageStore()),
      ChangeNotifierProvider<LearningStatisticsReader>.value(value: _FakeStatsReader()),
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
  });

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
}
