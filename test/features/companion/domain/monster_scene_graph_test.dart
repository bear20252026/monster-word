// companion 域：演出场景图（VPet Graph 结构的 Dart 重写）。
//
// ⚠️ 本机没有可用的 flutter test（365vpn 让 Dart VM 无法派生进程），
// 但 `lib/features/companion/domain/*` **只依赖 dart:core** ⇒ 可以临时写一个
// 纯 Dart 探针真跑同一批断言：
//   `dart.exe tool/_probe.dart`（探针放仓库内才解析得到 package:word_app）
// 2026-10-17 首次落地时就是这么验的（28 项全通过），探针跑完已删。
// 不要长期留探针：两套断言会漂移，flutter_test 是唯一事实来源。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/companion/domain/monster_event.dart';
import 'package:word_app/features/companion/domain/monster_scene.dart';
import 'package:word_app/features/companion/domain/monster_scene_graph.dart';

void main() {
  final t0 = DateTime(2026, 10, 17, 10);

  group('事件映射', () {
    test('答对/抚摸不抢戏（页面本身已有反馈）', () {
      final g = MonsterSceneGraph();
      expect(g.dispatch(MonsterEvent.answerCorrect, at: t0), isNull);
      expect(g.dispatch(MonsterEvent.petted, at: t0), isNull);
      expect(g.current, MonsterScene.idle);
    });

    test('答错 → 指提示；会话完成 → 总结；喂食 → 庆祝', () {
      expect(MonsterSceneGraph().dispatch(MonsterEvent.answerWrong, at: t0), MonsterScene.hinting);
      expect(MonsterSceneGraph().dispatch(MonsterEvent.sessionCompleted, at: t0), MonsterScene.summarizing);
      expect(MonsterSceneGraph().dispatch(MonsterEvent.fed, at: t0), MonsterScene.celebrating);
    });
  });

  group('冷却', () {
    test('提示冷却内不重放（防「答错→提示→再答错」频闪）', () {
      final g = MonsterSceneGraph();
      g.dispatch(MonsterEvent.answerWrong, at: t0);
      // 演出已结束、回到 idle，但冷却还没过
      g.tick(at: t0.add(const Duration(seconds: 3)));
      expect(
        g.dispatch(MonsterEvent.answerWrong, at: t0.add(const Duration(seconds: 5))),
        isNull,
        reason: '冷却 20s 内不重放',
      );
      expect(
        g.dispatch(MonsterEvent.answerWrong, at: t0.add(const Duration(seconds: 25))),
        MonsterScene.hinting,
        reason: '过冷却后可再次提示',
      );
    });
  });

  group('不可打断', () {
    test('庆祝演到一半不能被抢；结束后可以', () {
      final g = MonsterSceneGraph();
      g.dispatch(MonsterEvent.fed, at: t0);
      expect(
        g.dispatch(MonsterEvent.answerWrong, at: t0.add(const Duration(milliseconds: 500))),
        isNull,
        reason: '升羁绊/发币仪式被切走，比不演更差',
      );
      g.tick(at: t0.add(const Duration(seconds: 3)));
      expect(g.dispatch(MonsterEvent.answerWrong, at: t0.add(const Duration(seconds: 3))), MonsterScene.hinting);
    });
  });

  group('优先级', () {
    test('低优先级不抢占进行中的高优先级演出；高优先级可以', () {
      final g = MonsterSceneGraph();
      g.dispatch(MonsterEvent.sessionCompleted, at: t0); // priority 80
      expect(
        g.dispatch(MonsterEvent.sessionStarted, at: t0.add(const Duration(milliseconds: 100))), // 30
        isNull,
      );
      expect(
        g.dispatch(MonsterEvent.returnedAfterGap, at: t0.add(const Duration(milliseconds: 100))), // 90
        MonsterScene.greeting,
      );
    });
  });

  group('回落', () {
    test('一次性演出到点回落到基础场景（不是 idle）', () {
      final g = MonsterSceneGraph(base: MonsterScene.carrying);
      g.force(MonsterScene.hinting, at: t0);
      expect(g.tick(at: t0.add(const Duration(seconds: 1))), isNull, reason: '演出未结束不回退');
      expect(g.tick(at: t0.add(const Duration(seconds: 3))), MonsterScene.carrying);
    });

    test('持续态（idle）不会被 tick 反复触发', () {
      final g = MonsterSceneGraph();
      expect(g.tick(at: t0), isNull);
      expect(g.tick(at: t0.add(const Duration(minutes: 5))), isNull);
    });
  });

  test('场景表必须覆盖所有场景（新增场景忘补参数会当场抛）', () {
    for (final scene in MonsterScene.values) {
      expect(() => specOf(scene), returnsNormally, reason: '$scene 缺少调度参数');
    }
  });
}
