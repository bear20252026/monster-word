// 由 Claude 团队生成 | Monster Word App
// NoteRepositoryImpl — 笔记数据仓库实现（使用 SharedPreferences）

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_note.dart';
import 'note_repository.dart';

/// 笔记数据仓库的具体实现
///
/// 使用 SharedPreferences 存储笔记（与现有架构保持一致）
class NoteRepositoryImpl implements NoteRepository {
  static const _notesKey = 'notes_v1';

  @override
  Future<List<WordNote>> getNotesByWord(int wordId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('${_notesKey}_$wordId');
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((e) => WordNote.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<int> addNote(int wordId, String content, {String word = ''}) async {
    final notes = await getNotesByWord(wordId);
    final now = DateTime.now();
    final note = WordNote(
      id: now.millisecondsSinceEpoch,
      wordId: wordId,
      word: word,
      content: content,
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
    );
    notes.add(note);
    await _saveNotes(wordId, notes);
    return note.id ?? 0;
  }

  @override
  Future<int> insertNote(WordNote note) async {
    final notes = await getNotesByWord(note.wordId);
    notes.add(note);
    await _saveNotes(note.wordId, notes);
    return note.id ?? 0;
  }

  @override
  Future<int> updateNote(WordNote note) async {
    final notes = await getNotesByWord(note.wordId);
    final idx = notes.indexWhere((n) => n.id == note.id);
    if (idx >= 0) {
      notes[idx] = note;
      await _saveNotes(note.wordId, notes);
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteNote(int noteId) async {
    // 需要遍历所有 wordId 的笔记来找到并删除
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('${_notesKey}_'));
    for (final key in keys) {
      final wordId = int.tryParse(key.substring(_notesKey.length + 1));
      if (wordId == null) continue;
      final notes = await getNotesByWord(wordId);
      final len = notes.length;
      notes.removeWhere((n) => n.id == noteId);
      if (notes.length != len) {
        await _saveNotes(wordId, notes);
        return 1;
      }
    }
    return 0;
  }

  Future<void> _saveNotes(int wordId, List<WordNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(notes.map((n) => n.toMap()).toList());
    await prefs.setString('${_notesKey}_$wordId', jsonStr);
  }

  @override
  Future<List<Map<String, dynamic>>> getFavorites() async {
    // 收藏操作由 FavRepository 处理
    return [];
  }

  @override
  Future<int> addFavorite(int wordId) async {
    // 收藏操作由 FavRepository 处理
    return 0;
  }

  @override
  Future<int> removeFavorite(int wordId) async {
    // 收藏操作由 FavRepository 处理
    return 0;
  }

  @override
  Future<bool> isFavorite(int wordId) async {
    // 收藏操作由 FavRepository 处理
    return false;
  }
}
