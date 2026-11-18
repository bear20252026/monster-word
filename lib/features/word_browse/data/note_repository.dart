// 由 Claude 团队生成 | Monster Word App
// NoteRepository — 笔记数据访问抽象

import 'package:word_app/models/word_note.dart';

/// 笔记数据仓库接口
///
/// 第四轮审计 M13（2026-11-17）：从 core/repositories 迁至唯一消费域
/// word_browse 的 data 层（目录自定规则「单域入 feature/data」）；
/// 收藏四死桩方法已删除（事实来源是 FavRepository / FavSentenceDao）。
abstract class NoteRepository {
  /// 获取单词的所有笔记
  Future<List<WordNote>> getNotesByWord(int wordId);

  /// 全量笔记计数（跨所有单词，用于"我的内容-笔记"真实计数）
  Future<int> countAllNotes();

  /// 添加笔记（返回 noteId）
  Future<int> addNote(int wordId, String content, {String word = ''});

  /// 插入 WordNote 对象
  Future<int> insertNote(WordNote note);

  /// 更新笔记
  Future<int> updateNote(WordNote note);

  /// 删除笔记
  Future<int> deleteNote(int noteId);
}
