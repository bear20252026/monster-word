import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/account/presentation/my_equip_page.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/checkin/domain/checkin_status.dart';
import 'package:word_app/theme/skin_system.dart';

class _FakeCheckinReader implements CheckinStatusReader {
  @override
  Future<CheckinStatus> getStatus() async => throw UnimplementedError();

  @override
  Future<Set<String>> getCheckinDates() async => const {};

  @override
  Future<int> getStreakDays() async => 7;

  @override
  Future<bool> hasCheckedInToday() async => true;
}

/// REG-EQUIP-001：装备架三入口契约。
///
/// 装备架 = 当前皮肤 hero + 收藏章 + 连击徽章，三条目分别跳
/// appearance / redemption / checkInHistory。重设计不得丢失入口或数值展示。
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences().init();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('哑页')),
            body: Center(child: Text('ROUTE:${settings.name}')),
          ),
        ),
        home: SkinProvider(
          skin: SkinSystem(),
          child: Provider<CheckinStatusReader>.value(value: _FakeCheckinReader(), child: const MyEquipPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('陈列三入口与数值完整展示', (tester) async {
    await pumpPage(tester);

    // hero：当前主题名（Charter 衬线陈列卡）
    final skin = SkinSystem();
    expect(find.text(skin.currentTheme.name), findsOneWidget);
    expect(find.text('当前装备 · 主题外观'), findsOneWidget);

    // 收藏陈列分组 + 两行
    expect(find.text('收藏陈列'), findsOneWidget);
    expect(find.text('收藏章'), findsOneWidget);
    expect(find.text('连击徽章'), findsOneWidget);
    expect(find.text('0 枚'), findsOneWidget);
    expect(find.text('连击 7 天'), findsOneWidget);
  });

  testWidgets('三个入口分别导航到 appearance / redemption / checkInHistory', (tester) async {
    await pumpPage(tester);

    // hero → appearance
    await tester.tap(find.text(SkinSystem().currentTheme.name));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE:${RouteNames.appearance}'), findsOneWidget);

    // 返回后 → 收藏章 → redemption
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收藏章'));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE:${RouteNames.redemption}'), findsOneWidget);

    // 返回后 → 连击徽章 → checkInHistory
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('连击徽章'));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE:${RouteNames.checkInHistory}'), findsOneWidget);
  });
}
