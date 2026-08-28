import '../../../models/word.dart';

/// 考试速刷流程的词源读取端口。
///
/// 该端口与正式复习队列分离，保留速刷模式自身的候选排序和数量限制。
abstract interface class QuickReviewWordReader {
  Future<List<Word>> loadWords({int limit = 50});
}
