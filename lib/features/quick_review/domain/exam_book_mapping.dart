import 'package:word_app/features/quick_review/domain/exam_type.dart';
import 'package:word_app/models/book.dart';

/// 审计 R12（2026-11-16）：考试类型 → 词书匹配。
///
/// 词库无词级考试标签，但词书目录按考试命名（高考词汇/四级/雅思…）。
/// 旧实现 loadWords 恒全库随机 50，「高考必备/雅思核心」标签与实际词表不符。
/// 现按词书名/code 关键词匹配对应词书取词；匹配不到时调用方回退全库随机
/// 并在 UI 如实提示（不假装词表已按考试过滤）。
///
/// 纯领域函数（R5：只依赖 models 与同域枚举），可表驱动单测。

/// 各考试类型的词书匹配关键词（小写包含匹配；顺序即优先级）。
const Map<ExamType, List<String>> kExamBookKeywords = {
  // 只用有把握的关键词：双字母缩写（gk/ky/ys/tf）子串误配面太大，宁可回退
  // 全库随机+如实提示，也不把无关词书当考试词表。
  ExamType.cet4: ['cet4', '四级'],
  ExamType.cet6: ['cet6', '六级'],
  ExamType.gaokao: ['gaokao', '高考'],
  ExamType.kaoyan: ['kaoyan', '考研'],
  ExamType.ielts: ['ielts', '雅思'],
  ExamType.toefl: ['toefl', '托福'],
};

/// 排除词：命中即不算该考试词书（防 PETS4/公共英语 误配 CET4）。
/// 第三轮 T5：专业英语（TEM4/TEM8，「专业四级/专四/专业八级/专八」）同样含
/// 「四级」字样但**不是** CET——旧排除词只挡 PETS，TEM 词书被误作 CET 词源。
/// 当前 ExamType 无 TEM 选项，这些书对全部类型都排除（宁回退全库+如实提示）。
const List<String> _kExcludeKeywords = [
  'pets',
  '公共英语',
  'tem4',
  'tem8',
  'tem-4',
  'tem-8',
  '专业四级',
  '专业六级',
  '专业八级',
  '专四',
  '专八',
  '英语专业',
];

/// 返回匹配 [type] 的词书（可能多本，如四级真题+四级词汇）；无匹配返回空。
List<Book> matchExamBooks(ExamType type, List<Book> books) {
  final keywords = kExamBookKeywords[type] ?? const [];
  if (keywords.isEmpty) return const [];
  return books.where((b) {
    final haystack = '${b.name} ${b.code}'.toLowerCase();
    if (_kExcludeKeywords.any(haystack.contains)) return false;
    return keywords.any(haystack.contains);
  }).toList();
}
