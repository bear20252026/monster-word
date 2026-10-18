// companion 状态层：把 domain 的规则接到 UI 之前的最后一层。
//
// 重点守两件事：
// 1. **同一类建议不重复刷新台词**（否则每次 rebuild 换一句话，看着像在抖）
// 2. **没话说就不留气泡**（不硬凑是产品红线）
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/core/utils/monster_event.dart';
import 'package:word_app/core/utils/monster_initiative.dart';
import 'package:word_app/core/utils/monster_scene.dart';
import 'package:word_app/features/companion/presentation/monster_companion_state.dart';

void main() {
  setUp(MonsterSpeech.resetForTest);
  tearDown(MonsterSpeech.resetForTest);

  test('到期够多且今天没学 → 有话要说', () {
    final state = MonsterCompanionState();
    state.refreshInitiative(const MonsterInitiativeInput(dueCount: 25));

    expect(state.initiative?.initiative, MonsterInitiative.proposeReview);
    expect(state.line, isNotNull, reason: '有建议就该有一句话（预算内）');
    expect(state.line, isNotEmpty);
  });

  test('今天已经学过 → 没话说，且气泡清空（不硬凑）', () {
    final state = MonsterCompanionState();
    state.refreshInitiative(const MonsterInitiativeInput(dueCount: 25));
    expect(state.line, isNotNull);

    state.refreshInitiative(const MonsterInitiativeInput(dueCount: 25, studiedToday: true));
    expect(state.initiative, isNull);
    expect(state.line, isNull, reason: '建议消失后气泡必须一起消失，不能留残影');
  });

  test('同类建议重复刷新不换台词（避免看着像在抖）', () {
    final state = MonsterCompanionState();
    state.refreshInitiative(const MonsterInitiativeInput(dueCount: 25));
    final first = state.line;

    var notified = 0;
    state.addListener(() => notified++);
    state.refreshInitiative(const MonsterInitiativeInput(dueCount: 31));

    expect(state.line, first, reason: '同类建议只更新数据，不换文案');
    expect(notified, 0, reason: '没有可见变化就不该 notify（省一次重建）');
  });

  test('三词小组有文案槽 → 困难时刻必须说得出话', () {
    final state = MonsterCompanionState();
    state.refreshInitiative(const MonsterInitiativeInput(consecutiveWrong: 3));

    expect(state.initiative?.initiative, MonsterInitiative.proposeThreeWordGroup);
    expect(state.line, isNotNull, reason: '连续答错正是最需要开口的时刻，闭嘴等于没这个功能');
    // 文案必须来自那张表，不许在 companion 里另造一套。
    final allowed = MonsterSpeech.templatesOf(SpeechSlot.suggestThreeWordGroup).toSet();
    expect(allowed, contains(state.line));
  });

  test('每日主动预算用尽后不再开口（跨日才重置）', () {
    final state = MonsterCompanionState();
    // 反复「有建议 → 无建议 → 有建议」；每次有建议都会尝试说话，预算 3 条/日。
    final lines = <String?>[];
    for (var i = 0; i < 4; i++) {
      state.refreshInitiative(const MonsterInitiativeInput(dueCount: 25)); // 说话
      lines.add(state.line); // ← 必须在清空之前记录
      state.refreshInitiative(const MonsterInitiativeInput(dueCount: 0)); // 无建议 → 清空
    }
    expect(lines[0], isNotNull);
    expect(lines[1], isNotNull);
    expect(lines[2], isNotNull);
    expect(lines[3], isNull, reason: '第 4 次超出每日主动预算');
  });

  test('dispatch 只在场景真变化时通知', () {
    final state = MonsterCompanionState();
    final at = DateTime(2026, 10, 17, 10);

    var notified = 0;
    state.addListener(() => notified++);

    expect(state.dispatch(MonsterEvent.petted, at: at), isFalse, reason: '抚摸不抢戏');
    expect(notified, 0);

    expect(state.dispatch(MonsterEvent.answerWrong, at: at), isTrue);
    expect(state.scene, MonsterScene.hinting);
    expect(notified, 1);
  });

  group('作答事件（页面只报对错，升级由本层判断）', () {
    final t0 = DateTime(2026, 10, 17, 10);

    test('连续答错达阈值 → 升级为 regrouping（三词小组）', () {
      final state = MonsterCompanionState();
      addTearDown(state.dispose);

      state.dispatch(MonsterEvent.answerWrong, at: t0);
      expect(state.scene, MonsterScene.hinting, reason: '第一次错只是指提示');

      state.dispatch(MonsterEvent.answerWrong, at: t0.add(const Duration(seconds: 1)));
      state.dispatch(MonsterEvent.answerWrong, at: t0.add(const Duration(seconds: 2)));
      expect(state.scene, MonsterScene.regrouping, reason: '第 3 次错要升级，而不是继续提示');
    });

    test('答对清零：2 错 + 1 对 + 1 错 不升级', () {
      final state = MonsterCompanionState();
      addTearDown(state.dispose);

      state.dispatch(MonsterEvent.answerWrong, at: t0);
      state.dispatch(MonsterEvent.answerWrong, at: t0.add(const Duration(seconds: 1)));
      state.dispatch(MonsterEvent.answerCorrect, at: t0.add(const Duration(seconds: 2)));
      state.dispatch(MonsterEvent.answerWrong, at: t0.add(const Duration(seconds: 3)));

      expect(state.scene, isNot(MonsterScene.regrouping), reason: '连击中断后要重新数');
    });

    test('答对本身不切换场景（页面已有对勾反馈，不抢戏）', () {
      final state = MonsterCompanionState();
      addTearDown(state.dispose);

      expect(state.dispatch(MonsterEvent.answerCorrect, at: t0), isFalse);
      expect(state.scene, MonsterScene.idle);
    });

    test('一次性演出过期后，下一个事件先回落再判定（提示不会一直挂着）', () {
      final state = MonsterCompanionState();
      addTearDown(state.dispose);

      state.dispatch(MonsterEvent.answerWrong, at: t0);
      expect(state.scene, MonsterScene.hinting);

      // 提示 hold=2s：3s 后再来一个「答对」事件 —— 应先回落 idle。
      state.dispatch(MonsterEvent.answerCorrect, at: t0.add(const Duration(seconds: 3)));
      expect(state.scene, MonsterScene.idle, reason: '过期的一次性演出必须自动回落');
    });
  });
}
