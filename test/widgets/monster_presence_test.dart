// 全局怪兽浮层：守住「全 app 只有一只」这条契约。
//
// 这是 2026-10-17 那次返工的直接原因：首页 header 画一只、学习页画一只、
// 复习页没有 —— 那不是宠物，是三份互不相干的贴图。VPet 的做法是怪兽只有一个
// 显示面（`Display/Main.xaml`）住在独立窗口里，页面根本不参与。
// 本文件守的就是这个结构。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
    final app = MaterialApp(
      // 与 app.dart 的真实装配一致：怪兽挂在 builder 上，位于 Navigator 之上。
      builder: (context, child) => MonsterPresenceHost(child: child ?? const SizedBox.shrink()),
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
    await tester.pumpAndSettle();

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
