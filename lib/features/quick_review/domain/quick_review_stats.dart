// 由 Claude 团队生成 | Monster Word App
//
// 考试速刷功能域 — 领域层：速刷统计值对象
//
/// 速刷过程的统计数据（纯领域模型，无框架依赖）。
class QuickReviewStats {
  int total = 0;
  int correct = 0;
  int wrong = 0;
  int skipped = 0;
  int totalTime = 0; // 秒

  double get accuracy => total == 0 ? 0 : correct / total;
  String get accuracyPercent => '${(accuracy * 100).toStringAsFixed(1)}%';
  String get timeFormatted {
    final min = totalTime ~/ 60;
    final sec = totalTime % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
