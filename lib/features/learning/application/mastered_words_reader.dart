import 'package:word_app/models/word.dart';

/// 已掌握词表的只读应用端口。
///
/// 手动掌握标记与词库单词是两个独立事实，数据适配器负责将它们解析为完整
/// [Word] 模型，页面和状态层不直接组合仓储。
abstract interface class MasteredWordsReader {
  Future<List<Word>> loadWords();

  /// 读取原始掌握词文本，供只关心字符串身份的状态使用。
  Future<List<String>> loadTexts();
}
