// 首屏怪兽舞台：可测性红线是「没有 companion 装配时也不能炸」。
//
// 本仓踩过 3 次同类坑：widget 测试是最小装配，页面非空读 Provider 会抛
// ProviderNotFoundException，把整条交互打断（表现为「找不到预期文案」）。
// 舞台用 `watch<MonsterCompanionController?>()`（provider 内部按
// `_InheritedProviderScope<T?>` 查，查不到且 `null is T` 时返回 null），
// 所以这里专门守一条「无装配」用例。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/utils/monster_event.dart';
import 'package:word_app/core/utils/monster_initiative.dart';
import 'package:word_app/core/utils/monster_scene.dart';
import 'package:word_app/features/companion/application/monster_companion_port.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/monster_home_stage.dart';

class _FakeController extends ChangeNotifier implements MonsterCompanionController {
  _FakeController({this.line});

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
  Widget host(Widget child, {MonsterCompanionController? controller}) {
    return SkinProvider(
      skin: SkinSystem(),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: controller == null
                ? child
                : ListenableProvider<MonsterCompanionController>.value(value: controller, child: child),
          ),
        ),
      ),
    );
  }

  testWidgets('没有 companion 装配时按待机渲染，不抛 ProviderNotFound', (tester) async {
    await tester.pumpWidget(host(const MonsterStage()));

    expect(tester.takeException(), isNull);
    expect(find.byType(MonsterStage), findsOneWidget);
  });

  testWidgets('有台词时出现气泡；台词消失后气泡一起消失', (tester) async {
    final controller = _FakeController(line: '今天还有 30 个词到期');
    await tester.pumpWidget(host(const MonsterStage(), controller: controller));

    expect(find.text('今天还有 30 个词到期'), findsOneWidget);

    controller.line = null;
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('今天还有 30 个词到期'), findsNothing, reason: '没话说就必须收气泡，不能留残影');
  });

  testWidgets('喂事实走 post-frame，不在 build 期间改状态', (tester) async {
    final controller = _FakeController();
    await tester.pumpWidget(
      host(
        MonsterStageWithFacts(dueCount: 25, studiedToday: false, builder: (_) => const MonsterStage()),
        controller: controller,
      ),
    );
    // 不抛「setState/notifyListeners during build」即为通过；再 pump 一帧确认稳定。
    await tester.pump();
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
