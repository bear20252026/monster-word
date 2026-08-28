// 由 Claude 团队生成 | Monster Word App
//
// 考试速刷功能域 — 领域层：考试类型枚举
//
/// 考试类型枚举，定义各考试模式的标签与答题限时。
enum ExamType {
  cet4('四级高频', 30),
  cet6('六级高频', 25),
  gaokao('高考必备', 35),
  kaoyan('考研核心', 20),
  ielts('雅思核心', 20),
  toefl('托福核心', 20);

  final String label;
  final int timeLimit; // 秒/词
  const ExamType(this.label, this.timeLimit);
}
