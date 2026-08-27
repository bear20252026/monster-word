/// 已掌握单词标记的数据访问抽象。
///
/// 使用单词字符串作为身份键，与既有 `mastered_words_v1` 持久化格式兼容。
abstract class MasteredRepository {
  Future<Set<String>> getMasteredWords();

  Future<void> toggleMastered(String word);

  bool isMastered(String word);

  int get masteredCount;
}
