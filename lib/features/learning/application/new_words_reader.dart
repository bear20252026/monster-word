import '../../../models/word.dart';

/// 将用户生词本记录解析为可展示词条的应用端口。
///
/// 生词本记录与词库单词是不同事实，数据适配器负责完成跨仓储解析和顺序保持。
abstract interface class NewWordsReader {
  /// 按加入生词本的时间倒序加载仍可从词库解析的单词。
  Future<List<Word>> loadWords({int? limit, int? offset});
}
