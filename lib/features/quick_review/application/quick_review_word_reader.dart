import 'package:word_app/features/quick_review/domain/exam_type.dart';
import 'package:word_app/models/word.dart';

/// 第三轮 T19：一次取词的结果——词表 + **实际来源**。
///
/// [fromExamBook]=false 表示本次词表来自全库随机（无匹配考试词书，或匹配书
/// 全为空壳词被过滤尽）。UI 提示必须以实际来源为准：旧实现只探测「目录里
/// 有没有匹配书」，匹配书全空壳回退全库时仍提示考试词书，口径误导。
class QuickReviewLoadResult {
  const QuickReviewLoadResult({required this.words, required this.fromExamBook});

  final List<Word> words;
  final bool fromExamBook;
}

/// 考试速刷流程的词源读取端口。
///
/// 该端口与正式复习队列分离，保留速刷模式自身的候选排序和数量限制。
abstract interface class QuickReviewWordReader {
  /// 取速刷词表。
  ///
  /// 审计 R12（2026-11-16）：[examType] 非空时优先从匹配考试词书取词
  /// （词库无词级考试标签，词书目录按考试命名）；匹配不到回退全库随机，
  /// 调用方经 [hasExamBooks] 在 UI 如实提示词源口径。
  Future<List<Word>> loadWords({int limit = 50, ExamType? examType});

  /// 第三轮 T19：取词并返回实际来源（UI 诚实提示的唯一依据）。
  Future<QuickReviewLoadResult> loadWordsWithSource({int limit = 50, ExamType? examType});

  /// 当前词库是否存在匹配 [examType] 的词书（UI 诚实提示用）。
  Future<bool> hasExamBooks(ExamType examType);
}
