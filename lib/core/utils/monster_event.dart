// 怪兽演出事件（companion 域，纯 Dart 零依赖）。
//
// 事件是「数据层 → 演出层」的唯一通道：学习/奖励/成长只报**事实**，
// 不直接指挥动画。这样演出层永远无权改数据（蓝图红线：怪兽是镜子，不是记账员）。

/// 触发演出的事实事件。
///
/// 命名用「用户做了什么」而不是「该演什么」——后者属于场景图，不属事件。
enum MonsterEvent {
  /// 进入学习会话（开始一起做事）。
  sessionStarted,

  /// 答对一题。
  answerCorrect,

  /// 答错一题（演出重点：给出实际帮助，不是卖萌）。
  answerWrong,

  /// 连续困难达到阈值（用于提议「三词小组」）。
  hardStreak,

  /// 一次会话完成。
  sessionCompleted,

  /// 隔了几天回来。
  returnedAfterGap,

  /// 被喂食（发币成功）。
  fed,

  /// 被抚摸（小屋撸怪）。
  petted,

  /// 进入复习流程（有积压要搬）。
  reviewStarted,
}
