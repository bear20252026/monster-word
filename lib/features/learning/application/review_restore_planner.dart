// 第四轮审计 M4（2026-11-17）：复习断点恢复决策下沉 application。
//
// 原 ReviewSessionState._planRestore 内联在 presentation（约 25 行纯决策），
// 与 learning 侧 planLearningResume（步骤3b 已下沉）不对称。现镜像同款范式：
// 只做决策不碰状态，presentation 拿到计划后自行重建引擎并通知。
// 无 SP/时钟依赖，可整表驱动单测覆盖。
import 'package:word_app/features/learning/application/review_session_snapshot.dart';
import 'package:word_app/models/word.dart';

/// 复习恢复计划：还要继续走的那批词 + 已消费的词 id。
class ReviewRestorePlan {
  const ReviewRestorePlan({required this.remaining, required this.doneIds});

  /// 按存档词序保留的剩余词（引擎重建必须保序，否则「上次做到第几步」错位）。
  final List<Word> remaining;

  /// 已消费的词 id（评分已落库 / 标记已掌握 / 已不再到期）。
  final Set<int> doneIds;
}

/// 恢复可行性判定；不可恢复时返回 null（调用方退回新局）。
///
/// 口径与原 _planRestore 逐条一致：
/// - 开局无到期词（兜底整本队列）不恢复——那不是到期词，不属于头目战口径；
/// - 「不在当前到期集合里」的词按已完成计——它要么评分已落库（所以不再 due），
///   要么已从词书删除；两种都不该再出现，更不能重答一次造成双计；
/// - 剩余为空 = 该局实际已走完，不恢复。
ReviewRestorePlan? planReviewRestore({
  required ReviewSessionSnapshot saved,
  required bool hadDueAtStart,
  required List<Word> loaded,
}) {
  if (!saved.hadDueAtStart || !hadDueAtStart) return null;
  final byId = {for (final word in loaded) word.id: word};
  final rated = saved.ratedIds.toSet();
  final remaining = <Word>[];
  final doneIds = <int>{};
  for (final id in saved.wordIds) {
    if (rated.contains(id)) {
      doneIds.add(id);
      continue;
    }
    final word = byId[id];
    if (word == null) {
      doneIds.add(id);
      continue;
    }
    remaining.add(word);
  }
  if (remaining.isEmpty) return null;
  return ReviewRestorePlan(remaining: remaining, doneIds: doneIds);
}
