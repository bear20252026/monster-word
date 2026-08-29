import '../../models/new_word_record.dart';
import '../../models/word.dart';

/// 用户生词本的数据访问抽象。
///
/// 生词本是用户手动标记的独立集合，不等同于未学习队列、FSRS 卡片、收藏或掌握标记。
abstract class NewWordRepository {
  /// 按加入时间倒序读取生词本记录。
  Future<List<NewWordRecord>> getNewWords({int? limit, int? offset});

  /// 将词库单词加入生词本；返回 true 表示本次新加入。
  Future<bool> addNewWord(Word word, {String source = 'manual'});

  /// 从生词本移除指定词库单词；返回 true 表示本次确实移除记录。
  Future<bool> removeNewWord(int wordId);

  /// 切换生词本状态；返回 true 表示切换后已加入。
  Future<bool> toggleNewWord(Word word, {String source = 'manual'});

  /// 查询指定词库单词是否已在生词本中。
  Future<bool> isNewWord(int wordId);

  /// 获取生词本数量。
  Future<int> getNewWordCount();
}
