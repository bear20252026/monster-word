// P3-4（架构审计 2026-11-12）：拼写判分纯规则（从 SpellingQuizController 抽出）。
//
// 判分是领域规则，不应埋在 presentation 的 ChangeNotifier 里——抽为纯函数后
// 可直接单测（大小写/空白/空串边界），控制器只委托。domain 纯净（R5）：零 Flutter 依赖。

/// 拼写判分：忽略首尾空白与大小写后比较。
///
/// [input] 为用户输入，[answer] 为目标单词。两者均 trim + toLowerCase 后全等才算对。
/// 空输入对非空答案判错；答案为空时仅空输入判对（防御边界，正常会话答案非空）。
///
/// 用户反馈修复（2026-11-14）：全等不中时，仅当双方都不含内部空白时再比
/// 「去掉连字符」的规范形，容忍 e-mail/email 变体；内部空白仍判错（不放宽）。
bool gradeSpelling(String input, String answer) {
  final a = input.trim().toLowerCase();
  final b = answer.trim().toLowerCase();
  if (a == b) return true;
  if (a.isEmpty || b.isEmpty) return false;
  if (a.contains(RegExp(r'\s')) || b.contains(RegExp(r'\s'))) return false;
  return a.replaceAll('-', '') == b.replaceAll('-', '');
}
