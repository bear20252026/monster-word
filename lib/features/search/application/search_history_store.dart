/// 搜索页所需的历史记录读写能力。
abstract interface class SearchHistoryStore {
  List<String> read();

  Future<void> add(String word);

  Future<void> clear();
}
