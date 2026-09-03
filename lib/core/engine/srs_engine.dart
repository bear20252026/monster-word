// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 学习评分等级定义（SM-2 引擎已删除：死代码清理，FSRS-6 为唯一在役引擎）
// 每个单词维护：记忆等级(0-5)、间隔天数、到期日、复习次数

/// 评分等级（学习时用户反馈）
enum RecallRating {
  again(0, '不认识'), // 完全忘记 → 重新学习
  hard(3, '模糊'), // 勉强想起 → 较短间隔
  good(4, '认识'), // 正常记忆 → 标准间隔
  easy(5, '熟练'); // 非常熟练 → 更长间隔

  const RecallRating(this.quality, this.label);
  final int quality;
  final String label;
}
