import 'package:word_app/models/word_note.dart';

/// 词条浏览流程所需的笔记读写能力。
///
/// 页面只通过该端口读取和修改笔记，不感知底层数据库或历史仓储的实现。
abstract interface class WordNotesStore {
  Future<List<WordNote>> listForWord(int wordId);

  /// 全量笔记计数（跨所有单词，"我的内容-笔记"真实计数）。
  Future<int> countAll();

  /// 新增笔记，返回持久化层生成的真实 ID（MW-41：ID 只允许由持久化层
  /// 生成——此前 UI 构造的 note 无 id，删除时 `note.id!` 直接崩溃）。
  Future<int> add(WordNote note);

  Future<void> update(WordNote note);

  Future<void> deleteById(int noteId);
}
