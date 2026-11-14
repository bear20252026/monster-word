import 'package:word_app/models/word.dart';
import 'package:word_app/core/repositories/word_repository.dart';
import 'package:word_app/features/quick_review/application/quick_review_word_reader.dart';

/// 基于既有单词仓储的考试速刷词源适配器。
class RepositoryQuickReviewWordReader implements QuickReviewWordReader {
  /// 显式注入（供测试覆盖）。
  RepositoryQuickReviewWordReader(WordRepository repository) : _repository = repository;

  final WordRepository _repository;

  @override
  Future<List<Word>> loadWords({int limit = 50}) async {
    // 用户反馈修复（2026-11-14）：旧实现 searchWords('') 返回字母序头部再按 id
    // 倒序，导致「考试速刷」永远刷同一批字母序头部词。改为全库随机取样。
    return _repository.getRandomWords(limit);
  }
}
