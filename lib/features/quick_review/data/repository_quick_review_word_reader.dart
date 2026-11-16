import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/core/repositories/word_repository.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/quick_review/application/quick_review_word_reader.dart';
import 'package:word_app/features/quick_review/domain/exam_book_mapping.dart';
import 'package:word_app/features/quick_review/domain/exam_type.dart';

/// 基于既有单词仓储的考试速刷词源适配器。
///
/// 审计 R12（2026-11-16）：按考试类型匹配词书取词（词库无词级考试标签，
/// 词书目录按考试命名）；匹配不到回退全库随机——UI 经 hasExamBooks 如实提示。
/// 目录读取经 book 域 application 端口（跨 feature 端口通道，R4 允许）；
/// 未注入目录（旧装配/测试）时行为等同旧版全库随机。
class RepositoryQuickReviewWordReader implements QuickReviewWordReader {
  /// 显式注入（供测试覆盖）。
  RepositoryQuickReviewWordReader(this._repository, {this.catalog});

  final WordRepository _repository;

  /// 词书目录端口（可选注入；未注入时行为等同旧版全库随机）。
  final BookCatalogReader? catalog;

  /// 词书目录缓存（一次加载；词库只读，目录不会运行时变化）。
  Future<List<Book>>? _booksCache;

  Future<List<Book>> _books() {
    final catalog = this.catalog;
    if (catalog == null) return Future.value(const []);
    return _booksCache ??= catalog.listBooks();
  }

  @override
  Future<bool> hasExamBooks(ExamType examType) async => matchExamBooks(examType, await _books()).isNotEmpty;

  @override
  Future<List<Word>> loadWords({int limit = 50, ExamType? examType}) async {
    if (examType != null) {
      final matched = matchExamBooks(examType, await _books());
      if (matched.isNotEmpty) {
        // 多本匹配词书时随机选一本（每轮切换有变化），书内取词后洗牌截断。
        final book = (matched..shuffle()).first;
        final words = await _repository.getWordsByBookId(book.id);
        if (words.isNotEmpty) {
          // 过滤无中文释义的空壳词（与学习队列同口径：宁少勿假）。
          final usable = words.where((w) => w.cleanInterpret.trim().isNotEmpty).toList()..shuffle();
          if (usable.isNotEmpty) return usable.take(limit).toList();
        }
        // 匹配书全为空壳词：回退全库随机（UI 仍按「有考试词书」提示，
        // 词表口径以实际取词为准，不静默假装）。
      }
    }
    // 用户反馈修复（2026-11-14）：旧实现 searchWords('') 返回字母序头部再按 id
    // 倒序，导致「考试速刷」永远刷同一批字母序头部词。改为全库随机取样。
    return _repository.getRandomWords(limit);
  }
}
