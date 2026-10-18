// 全局怪兽浮层：守住「全 app 只有一只」这条契约。
//
// 这是 2026-10-17 那次返工的直接原因：首页 header 画一只、学习页画一只、
// 复习页没有 —— 那不是宠物，是三份互不相干的贴图。VPet 的做法是怪兽只有一个
// 显示面（`Display/Main.xaml`）住在独立窗口里，页面根本不参与。
// 本文件守的就是这个结构。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/core/utils/monster_event.dart';
import 'package:word_app/core/utils/monster_initiative.dart';
import 'package:word_app/core/utils/monster_scene.dart';
import 'package:word_app/features/companion/application/monster_companion_port.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/monster_icon.dart';
import 'package:word_app/widgets/monster_presence.dart';

class _FakeCompanion extends ChangeNotifier implements MonsterCompanionController {
  _FakeCompanion({this.line});

  @override
  MonsterScene scene = MonsterScene.idle;

  @override
  String? line;

  @override
  void refreshInitiative(MonsterInitiativeInput input) {}

  @override
  bool dispatch(MonsterEvent event, {DateTime? at}) => false;

  @override
  bool tick({DateTime? at}) => false;
}

void main() {
  Widget host({MonsterCompanionController? companion, Widget? home}) {
    final navKey = GlobalKey<NavigatorState>();
    final app = MaterialApp(
      navigatorKey: navKey,
      // 命名路由占位页：断言「点怪兽 → 进我的空间」，也让「拖动不该跳转」可验证。
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: Center(child: Text('page:${settings.name}'))),
      ),
      // 与 app.dart 的真实装配一致：怪兽挂在 builder 上，位于 Navigator 之上。
      builder: (context, child) => MonsterPresenceHost(navigatorKey: navKey, child: child ?? const SizedBox.shrink()),
      home: home ?? const Scaffold(body: Center(child: Text('页面 A'))),
    );
    return SkinProvider(
      skin: SkinSystem(),
      child: companion == null
          ? app
          : ListenableProvider<MonsterCompanionController>.value(value: companion, child: app),
    );
  }

  testWidgets('任何页面都只有一只怪兽', (tester) async {
    await tester.pumpWidget(host());

    expect(find.byType(MonsterIcon), findsOneWidget);
    expect(find.byType(MonsterPresence), findsOneWidget);
  });

  testWidgets('换页后仍只有一只，且不重建（宠物跨路由常驻）', (tester) async {
    await tester.pumpWidget(host());

    final before = tester.state(find.byType(MonsterPresence));

    // 推一层新路由：内容换了，宠物必须还是同一个实例。
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('页面 B'))),
      ),
    );
    // ⚠️ 不能用 pumpAndSettle：怪兽的呼吸 bob 是无限循环动画，永远 settle 不了。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('页面 B'), findsOneWidget);
    expect(find.byType(MonsterIcon), findsOneWidget, reason: '换页不该多出一只');
    expect(tester.state(find.byType(MonsterPresence)), same(before), reason: '宠物跨路由必须常驻：重建会重放呼吸相位、丢掉正在演的场景');
  });

  testWidgets('companion 有话要说 → 不点也冒泡', (tester) async {
    await tester.pumpWidget(host(companion: _FakeCompanion(line: '今天还有 30 个词到期')));

    expect(find.text('今天还有 30 个词到期'), findsOneWidget);
  });

  testWidgets('没有 companion 装配时退化为待机，不抛异常', (tester) async {
    await tester.pumpWidget(host());

    final icon = tester.widget<MonsterIcon>(find.byType(MonsterIcon));
    expect(icon.sad, isFalse);
    expect(tester.takeException(), isNull);
  });

  // ── 拖动：桌面宠物得能被拎走 ──────────────────────────────────────────────
  testWidgets('拖着走：宠物跟手移动', (tester) async {
    await tester.pumpWidget(host());
    final start = tester.getTopLeft(find.byType(MonsterPresence));

    await tester.drag(find.byType(MonsterPresence), const Offset(-120, -100));
    await tester.pump();

    final moved = tester.getTopLeft(find.byType(MonsterPresence));
    expect(moved.dx, lessThan(start.dx), reason: '向左拖必须往左走');
    expect(moved.dy, lessThan(start.dy), reason: '向上拖必须往上走');
    // 容差留给手势 slop（起手那一段被 DragStartBehavior.start 吃掉），不苛求像素级相等。
    expect(start.dx - moved.dx, closeTo(120, 40));
    expect(start.dy - moved.dy, closeTo(100, 40));
  });

  testWidgets('拖出屏幕会被夹住：宠物始终完整可见', (tester) async {
    await tester.pumpWidget(host());
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;

    await tester.drag(find.byType(MonsterPresence), const Offset(-9999, -9999));
    await tester.pump();
    // 左上留白 = 8；顶部再让出气泡高度 28（否则长台词被屏幕顶边裁掉）。
    expect(tester.getTopLeft(find.byType(MonsterPresence)), const Offset(8, 28));

    await tester.drag(find.byType(MonsterPresence), const Offset(9999, 9999));
    await tester.pump();
    final tl = tester.getTopLeft(find.byType(MonsterPresence));
    expect(tl.dx, screen.width - kMonsterPresenceSize - 8);
    expect(tl.dy, screen.height - kMonsterPresenceSize - 8);
  });

  testWidgets('拖动不会误触发点击（拖动 ≠ 进我的空间）', (tester) async {
    await tester.pumpWidget(host());

    await tester.drag(find.byType(MonsterPresence), const Offset(-100, -100));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('page:/my_space'), findsNothing);
  });

  testWidgets('拖到别处后点一下仍然进我的空间', (tester) async {
    await tester.pumpWidget(host());

    await tester.drag(find.byType(MonsterPresence), const Offset(-200, -200));
    await tester.pump();
    await tester.tap(find.byType(MonsterPresence));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900)); // 800ms 节拍窗
    await tester.pump(const Duration(milliseconds: 400)); // 路由转场

    expect(find.text('page:/my_space'), findsOneWidget);
    // 排掉气泡的 1600ms 定时器，否则测试结束时报「Timer still pending」。
    await tester.pump(const Duration(milliseconds: 2000));
  });

  testWidgets('拖完的位置会记住：重建整棵树后回到同一处', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences().init();
    await tester.pumpWidget(host());
    final start = tester.getTopLeft(find.byType(MonsterPresence));

    await tester.drag(find.byType(MonsterPresence), const Offset(-200, -180));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10)); // 让写盘完成
    final dragged = tester.getTopLeft(find.byType(MonsterPresence));
    expect(dragged, isNot(start), reason: '先得真的拖动过');

    // 拆掉整棵树再装回来 = 模拟重启
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host());
    await tester.pump();

    final restored = tester.getTopLeft(find.byType(MonsterPresence));
    expect(restored.dx, closeTo(dragged.dx, 0.01));
    expect(restored.dy, closeTo(dragged.dy, 0.01));
  });

  test('场景 → 表情参数：每个场景都有映射，庆祝比待机更夸张', () {
    for (final scene in MonsterScene.values) {
      final e = sceneExpression(scene);
      expect(e.bellyScale, greaterThan(0), reason: '$scene 的肚子缩放必须是正数');
    }
    final idle = sceneExpression(MonsterScene.idle);
    final happy = sceneExpression(MonsterScene.celebrating);
    expect(happy.mouthOpen, greaterThan(idle.mouthOpen));
    expect(happy.cheekPuff, greaterThan(idle.cheekPuff));
  });

  test('指提示不卖萌，连续困难才陪着难过（帮助时刻不抢戏）', () {
    final hint = sceneExpression(MonsterScene.hinting);
    final regroup = sceneExpression(MonsterScene.regrouping);
    expect(hint.sad, isFalse, reason: '答错时是帮忙，不是陪着难过');
    expect(regroup.sad, isTrue, reason: '连续困难时才陪着难过（不评判）');
    expect(hint.mouthOpen, lessThan(sceneExpression(MonsterScene.celebrating).mouthOpen));
  });
}
