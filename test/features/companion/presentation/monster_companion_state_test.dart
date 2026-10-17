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

  test('三词小组没有文案槽 → 有建议但不出气泡', () {
    final state = MonsterCompanionState();
    state.refreshInitiative(const MonsterInitiativeInput(consecutiveWrong: 3));

    expect(state.initiative?.initiative, MonsterInitiative.proposeThreeWordGroup);
    expect(state.line, isNull, reason: '没有现成文案就闭嘴，不在 companion 里另造一套');
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
}
