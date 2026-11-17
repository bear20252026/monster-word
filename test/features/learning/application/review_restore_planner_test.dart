// 第四轮审计 M4（2026-11-17）：复习恢复决策纯函数整表驱动测试。
// 口径与原 ReviewSessionState._planRestore 逐条一致（下沉不改语义）。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/learning/application/review_restore_planner.dart';
import 'package:word_app/features/learning/application/review_session_snapshot.dart';
import 'package:word_app/models/word.dart';

Word w(int id) => Word(id: id, word: 'w$id', interpret: '[{"t":"n.","def":[{"cn":"释$id"}]}]');

ReviewSessionSnapshot snap({
  List<int> wordIds = const [1, 2, 3],
  List<int> ratedIds = const [],
  bool hadDueAtStart = true,
}) {
  return ReviewSessionSnapshot(
    sessionId: 's1',
    wordIds: wordIds,
    index: ratedIds.length,
    ratedIds: ratedIds,
    pending: null,
    hadDueAtStart: hadDueAtStart,
    dueAtStart: wordIds.length,
    updatedAt: DateTime.now().millisecondsSinceEpoch,
  );
}

void main() {
  test('开局无到期词（兜底整本队列）：不恢复', () {
    expect(planReviewRestore(saved: snap(), hadDueAtStart: false, loaded: [w(1), w(2), w(3)]), isNull);
    expect(
      planReviewRestore(saved: snap(hadDueAtStart: false), hadDueAtStart: true, loaded: [w(1), w(2), w(3)]),
      isNull,
    );
  });

  test('全部已评分：剩余为空不恢复', () {
    expect(
      planReviewRestore(
        saved: snap(ratedIds: [1, 2, 3]),
        hadDueAtStart: true,
        loaded: [w(1), w(2), w(3)],
      ),
      isNull,
    );
  });

  test('正常恢复：剩余保存档词序，已评分计 done', () {
    final plan = planReviewRestore(
      saved: snap(ratedIds: [1]),
      hadDueAtStart: true,
      loaded: [w(3), w(2)],
    );
    expect(plan, isNotNull);
    expect(plan!.remaining.map((e) => e.id), [2, 3], reason: '必须按存档词序而非加载序');
    expect(plan.doneIds, {1});
  });

  test('不在当前到期集合的词按已完成计（已落库或已删词，不重答防双计）', () {
    final plan = planReviewRestore(saved: snap(), hadDueAtStart: true, loaded: [w(2)]);
    expect(plan, isNotNull);
    expect(plan!.remaining.map((e) => e.id), [2]);
    expect(plan.doneIds, {1, 3});
  });

  test('全部词都不在到期集合：剩余为空不恢复', () {
    expect(planReviewRestore(saved: snap(), hadDueAtStart: true, loaded: [w(9)]), isNull);
  });

  test('空存档词序：不恢复', () {
    expect(
      planReviewRestore(
        saved: snap(wordIds: []),
        hadDueAtStart: true,
        loaded: [w(1)],
      ),
      isNull,
    );
  });
}
