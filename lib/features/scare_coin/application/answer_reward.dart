// 答对即时奖励窄端口（结构修复步骤4，2026-11-16）。
//
// 从上帝端口 ScareCoinStore 拆出的「答题奖励」能力组。学习页等只需答对发币
// 能力的消费方依赖本窄端口。
abstract interface class AnswerReward {
  /// 答对即时奖励上限（＋1／次，每日封顶，防刷）。
  int get answerRewardDailyCap;

  /// 答对即时奖励：未达日上限发＋1 并返回 1，否则返回 0（可重入）。
  Future<int> grantAnswerReward();
}
