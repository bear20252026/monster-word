// 由 Claude 团队生成 | Monster Word App
// NoteRepository — 笔记数据访问抽象

import '../../models/word_note.dart';

/// 笔记数据仓库接口
///
/// 提供单词笔记、收藏等数据访问抽象。
abstract class NoteRepository {
  /// 获取单词的所有笔记
  Future<List<WordNote>> getNotesByWord(int wordId);

  /// 添加笔记（返回 noteId）
  Future<int> addNote(int wordId, String content, {String word = ''});

  /// 插入 WordNote 对象
  Future<int> insertNote(WordNote note);

  /// 更新笔记
  Future<int> updateNote(WordNote note);

  /// 删除笔记
  Future<int> deleteNote(int noteId);

  /// 获取收藏列表
  Future<List<Map<String, dynamic>>> getFavorites();

  /// 添加收藏
  Future<int> addFavorite(int wordId);

  /// 取消收藏
  Future<int> removeFavorite(int wordId);

  /// 检查是否已收藏
  Future<bool> isFavorite(int wordId);
}
