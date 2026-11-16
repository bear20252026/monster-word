import 'package:word_app/features/learning/application/learning_progress_port.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';

/// 断点恢复决策（结构修复步骤3b：从 LearningSessionState.loadBook 下沉的纯编排）。
///
/// 只做决策不碰状态：presentation 拿到计划后自行应用索引/重建队列并通知。
/// 无 SharedPreferences / 时钟依赖，可被整表驱动单测覆盖。
sealed class LearningResumePlan {
  const LearningResumePlan();
}

/// 无快照 / 异书 / 快照指针越界 / 新队列为空：不恢复。
class LearningResumeNone extends LearningResumePlan {
  const LearningResumeNone();
}

/// 同书且快照词在新抽样队列中：按词身份反查的真实位置恢复。
///
/// R2-06：不能复用旧数字 index——新队列是重新随机抽样 + 重新洗牌的，
/// 同一个 index 指向的是另一个词。
class LearningResumeAtIndex extends LearningResumePlan {
  const LearningResumeAtIndex(this.index);
  final int index;
}

/// 快照词不在本次抽样里（每日目标 10～50 词而词书数千词时是常态）：
/// 按快照队列原序重建会话——同一批词、同一顺序、同一位置，这才是快照本来的语义。
class LearningResumeRebuild extends LearningResumePlan {
  const LearningResumeRebuild({required this.queue, required this.index});
  final List<Word> queue;
  final int index;
}

/// MW-27 断点②：计算「继续上次学习」的恢复计划。
///
/// [resume] 启动时暂存的进度快照（一次性消费，调用方无论是否应用都应清空）；
/// [book] 本次加载的词书；[newQueue] 本次重新抽样/洗牌后的队列。
LearningResumePlan planLearningResume({
  required LearningProgress? resume,
  required Book book,
  required List<Word> newQueue,
}) {
  if (resume == null || newQueue.isEmpty) return const LearningResumeNone();
  if (resume.currentBook.id != book.id) return const LearningResumeNone();
  final resumeWord = resume.currentIndex < resume.queue.length ? resume.queue[resume.currentIndex] : null;
  if (resumeWord == null) return const LearningResumeNone();
  final actualIndex = newQueue.indexWhere((w) => w.id == resumeWord.id);
  if (actualIndex >= 0) return LearningResumeAtIndex(actualIndex);
  return LearningResumeRebuild(queue: resume.queue, index: resume.currentIndex.clamp(0, resume.queue.length - 1));
}
