// 更多设置页 widget 测试（测试补齐批次 4 / P4-21：776 行页面此前零覆盖）。
//
// 覆盖：分组渲染 smoke、真实版本号展示（PackageInfo mock）、词库重建
// 确认→执行→结果流（成功/取消/异常三路）、举报与法务弹窗。
// 坑：PackageInfo 未 mock 时 initState 走 catchError（版本行空态），需
// pumpAndSettle；重建服务为具体类，fake 用 implements 覆盖全部成员。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:word_app/core/application/wordbook_maintenance_service.dart';
import 'package:word_app/features/settings/application/update_check_service.dart';
import 'package:word_app/features/settings/domain/version_compare.dart';
import 'package:word_app/features/settings/presentation/more_settings_page.dart';
import 'package:word_app/theme/skin_system.dart';

class _FakeMaintenance implements WordBookMaintenanceService {
  _FakeMaintenance({this.result, this.throwOnRebuild = false});

  final DbRebuildResult? result;
  final bool throwOnRebuild;
  int rebuildCalls = 0;

  @override
  Future<DbRebuildResult> forceRebuild() async {
    rebuildCalls++;
    if (throwOnRebuild) throw StateError('boom');
    return result!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUpdate implements UpdateCheckService {
  @override
  Future<UpdateCheckResult> check({required String currentVersion}) async =>
      const UpdateCheckResult(currentVersion: '9.9.9', latestVersion: '9.9.9', releaseUrl: '', hasUpdate: false);
}

Future<void> _pump(WidgetTester tester, {required _FakeMaintenance maintenance}) async {
  // 放大视口：ListView 惰性构建会让屏幕外分组不在 widget 树中
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    Provider<WordBookMaintenanceService>.value(
      value: maintenance,
      child: MaterialApp(
        home: SkinProvider(
          skin: SkinSystem(),
          child: MoreSettingsPage(updateServiceOverride: _FakeUpdate()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Monster Word',
      packageName: 'test',
      version: '9.9.9',
      buildNumber: '1',
      buildSignature: 'sig',
    );
  });

  const groupTitles = ['账号信息', '帮助与反馈', '评价应用', '检查更新', '更新词库数据', '推荐给好友', '兑换中心', '违法不良信息举报', '服务条款', '隐私协议', '关于我们'];

  testWidgets('渲染全部设置分组与退出登录', (tester) async {
    await _pump(
      tester,
      maintenance: _FakeMaintenance(
        result: const DbRebuildResult(success: true, books: 1, words: 1, links: 1, message: ''),
      ),
    );

    for (final t in groupTitles) {
      expect(find.text(t), findsOneWidget, reason: '缺少设置项：$t');
    }
    expect(find.text('退出登录'), findsOneWidget);
    expect(find.text('更多设置'), findsOneWidget, reason: '导航栏标题');
  });

  testWidgets('版本号来自 PackageInfo 并展示在评价应用副标题', (tester) async {
    await _pump(
      tester,
      maintenance: _FakeMaintenance(
        result: const DbRebuildResult(success: true, books: 1, words: 1, links: 1, message: ''),
      ),
    );

    expect(find.text('v9.9.9'), findsNWidgets(2), reason: '评价应用与关于我们两处副标题');
  });

  testWidgets('词库重建：确认后执行并在结果弹窗展示完整性计数', (tester) async {
    final maintenance = _FakeMaintenance(
      result: const DbRebuildResult(success: true, books: 3, words: 20000, links: 120, message: '词库重建完成，数据完整'),
    );
    await _pump(tester, maintenance: maintenance);

    await tester.tap(find.text('更新词库数据'));
    await tester.pumpAndSettle();
    expect(find.text('更新词库数据'), findsNWidgets(2), reason: '确认弹窗标题与入口 cell 同名并存');

    await tester.tap(find.text('立即重建'));
    await tester.pumpAndSettle();

    expect(maintenance.rebuildCalls, 1);
    expect(find.text('更新成功'), findsOneWidget);
    expect(find.textContaining('3 本词书 / 20000 词条 / 120 条关联'), findsOneWidget);
  });

  testWidgets('词库重建：取消则不触发重建', (tester) async {
    final maintenance = _FakeMaintenance(
      result: const DbRebuildResult(success: true, books: 1, words: 1, links: 1, message: ''),
    );
    await _pump(tester, maintenance: maintenance);

    await tester.tap(find.text('更新词库数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(maintenance.rebuildCalls, 0, reason: '取消不得触发 forceRebuild');
    expect(find.text('更新成功'), findsNothing);
  });

  testWidgets('词库重建：异常走 SnackBar 失败反馈', (tester) async {
    final maintenance = _FakeMaintenance(result: null, throwOnRebuild: true);
    await _pump(tester, maintenance: maintenance);

    await tester.tap(find.text('更新词库数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('立即重建'));
    await tester.pumpAndSettle();

    expect(find.textContaining('词库重建失败'), findsOneWidget);
    expect(find.text('更新成功'), findsNothing);
  });

  testWidgets('举报弹窗展示官方渠道', (tester) async {
    await _pump(
      tester,
      maintenance: _FakeMaintenance(
        result: const DbRebuildResult(success: true, books: 1, words: 1, links: 1, message: ''),
      ),
    );

    await tester.tap(find.text('违法不良信息举报'));
    await tester.pumpAndSettle();

    expect(find.text('举报渠道'), findsOneWidget);
    expect(find.textContaining('12377'), findsOneWidget, reason: '中央网信办电话与官网同 channel 行');
    expect(find.textContaining('公安报警'), findsOneWidget);
  });

  testWidgets('服务条款弹窗本地展示占位说明', (tester) async {
    await _pump(
      tester,
      maintenance: _FakeMaintenance(
        result: const DbRebuildResult(success: true, books: 1, words: 1, links: 1, message: ''),
      ),
    );

    await tester.tap(find.text('服务条款'));
    await tester.pumpAndSettle();

    expect(find.text('服务条款'), findsNWidgets(2), reason: '弹窗标题与入口 cell 并存');
    expect(find.textContaining('正在完善独立的服务条款文本'), findsOneWidget);
  });
}
