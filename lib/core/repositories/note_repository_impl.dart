// 由 Claude 团队生成 | Monster Word App
// NoteRepositoryImpl — 笔记数据仓库实现（使用 SharedPreferences）

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';

import 'package:word_app/models/word_note.dart';
import 'package:word_app/core/repositories/note_repository.dart';

/// 笔记数据仓库的具体实现
///
/// 使用 SharedPreferences 存储笔记（与现有架构保持一致）
class NoteRepositoryImpl implements NoteRepository {
  static const _notesKey = 'notes_v1';

  // MEM/U5：全量计数缓存（键集 → 总数）。笔记写入全部经由本仓储，任意写
  // 即失效；避免每次计数都扫描并 jsonDecode 全部笔记键。
  int? _cachedTotal;
  Set<String>? _cachedKeys;

  /// 写串行闸：add/update/delete 都是「整键 JSON 读-改-写」，无闸时并发
  /// 添加两条笔记会让后落盘的旧列表覆盖先写的新条目（审计：丢笔记窗口）。
  Future<void> _writeQueue = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final run = _writeQueue.then((_) => action());
    _writeQueue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  @override
  Future<List<WordNote>> getNotesByWord(int wordId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('${_notesKey}_$wordId');
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list.map((e) => WordNote.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e, s) {
      reportSwallowedError('笔记列表解析失败 wordId=$wordId', e, s);
      return [];
    }
  }

  @override
  Future<int> countAllNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '${_notesKey}_';
    final keys = prefs.getKeys().where((key) => key.startsWith(prefix)).toSet();
    final cachedTotal = _cachedTotal;
    final cachedKeys = _cachedKeys;
    if (cachedTotal != null && cachedKeys != null && cachedKeys.length == keys.length && cachedKeys.containsAll(keys)) {
      return cachedTotal;
    }
    // 笔记按 wordId 分键存储（notes_v1_<wordId>），全量计数 = 扫描所有笔记键求和。
    var total = 0;
    for (final key in keys) {
      final jsonStr = prefs.getString(key);
      if (jsonStr == null || jsonStr.isEmpty) continue;
      try {
        total += (jsonDecode(jsonStr) as List).length;
      } catch (e, s) {
        reportSwallowedError('笔记计数解析失败 key=$key', e, s);
      }
    }
    _cachedTotal = total;
    _cachedKeys = keys;
    return total;
  }

  /// 数据层审计 P3：主键 = 毫秒时间戳，同毫秒两条会冲突（update/delete
  /// 只命中第一条），时钟回拨产生重复键。用单调递增哨兵兜底。
  int _lastNoteId = 0;

  int _nextNoteId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now > _lastNoteId) {
      _lastNoteId = now;
    } else {
      _lastNoteId++;
    }
    return _lastNoteId;
  }

  @override
  Future<int> addNote(int wordId, String content, {String word = ''}) =>
      _serialized(() => _addNoteLocked(wordId, content, word: word));

  Future<int> _addNoteLocked(int wordId, String content, {String word = ''}) async {
    final notes = await getNotesByWord(wordId);
    final now = DateTime.now();
    final note = WordNote(
      id: _nextNoteId(),
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
  Future<int> insertNote(WordNote note) => _serialized(() => _insertNoteLocked(note));

  Future<int> _insertNoteLocked(WordNote note) async {
    final notes = await getNotesByWord(note.wordId);
    notes.add(note);
    await _saveNotes(note.wordId, notes);
    return note.id ?? 0;
  }

  @override
  Future<int> updateNote(WordNote note) => _serialized(() => _updateNoteLocked(note));

  Future<int> _updateNoteLocked(WordNote note) async {
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
  Future<int> deleteNote(int noteId) => _serialized(() => _deleteNoteLocked(noteId));

  Future<int> _deleteNoteLocked(int noteId) async {
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
    // MEM/U5：任意写入使全量计数缓存失效
    _cachedTotal = null;
    _cachedKeys = null;
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
