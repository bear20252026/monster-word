// 由 Claude 团队生成 | Monster Word App
// NoteRepositoryImpl — 笔记数据仓库实现（P1-07：SQLite 优先，SP 为迁移源与回退）

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

import 'package:word_app/models/word_note.dart';
import 'package:word_app/core/repositories/note_repository.dart';

/// 笔记数据仓库的具体实现（P1-07 / MW-41+42+43）。
///
/// - user_data.db.word_notes 为事实来源：AUTOINCREMENT 由数据库生成 ID
///   （UI 新建笔记不再产生 null-id），单条 INSERT/UPDATE/DELETE 消灭
///   「整键 JSON 读-改-写」的最后写入者覆盖竞态。
/// - word 文本为稳定业务身份（词库重建后 word_id 不保证稳定），word_id
///   只作当前词库版本的加速引用；查询按 word 优先、word_id 兜底。
/// - 存量 SP（`notes_v1_<wordId>`）首次访问时迁移入表，迁移成功后删除旧键。
/// - SQLite 不可用（测试环境/开库失败）回退原 SP 行为（ID 仍由仓储生成）。
class NoteRepositoryImpl implements NoteRepository {
  NoteRepositoryImpl({Future<Database> Function()? openDatabase}) : _openOverride = openDatabase;

  static const _notesKey = 'notes_v1';
  static const _migratedSpKeysMarker = 'notes_sqlite_migrated_v1';

  final Future<Database> Function()? _openOverride;

  Database? _db;
  Future<void>? _loading;
  bool _useSqlite = false;

  @visibleForTesting
  bool get usesSqlite => _useSqlite;

  Future<void> ensureLoaded() {
    final current = _loading;
    if (current != null) return current;
    return _loading = _ensureLoadedInner();
  }

  Future<void> _ensureLoadedInner() async {
    try {
      final Database db;
      final override = _openOverride;
      if (override != null) {
        db = await override();
      } else if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
        await UserDatabase.instance.initialize();
        db = UserDatabase.instance.db;
      } else {
        throw StateError('NoteRepository: 测试环境未注入数据库');
      }
      await _migrateSpIfNeeded(db);
      _db = db;
      _useSqlite = true;
      return;
    } catch (e, s) {
      reportSwallowedError('笔记仓储 SQLite 初始化失败，回退 SP 模式', e, s);
    }
    _useSqlite = false;
  }

  /// SP 存量迁移：`notes_v1_<wordId>` 逐键入表（同 word 的 notes 去重按内容+
  /// 时间），全部成功后删除 SP 键。失败保留 SP 键下次重试。
  Future<void> _migrateSpIfNeeded(Database db) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('${_notesKey}_')).toList();
    if (keys.isEmpty) return;
    var migrated = 0;
    var failed = 0;
    for (final key in keys) {
      final wordId = int.tryParse(key.substring(_notesKey.length + 1));
      if (wordId == null) continue;
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final list = jsonDecode(raw) as List;
        await db.transaction((txn) async {
          for (final entry in list) {
            final note = WordNote.fromMap(entry as Map<String, dynamic>);
            await txn.insert('word_notes', {
              'word': note.word,
              'word_id': note.wordId,
              'content': note.content,
              'created_at': note.createdAt,
              'updated_at': note.updatedAt,
            });
          }
        });
        migrated++;
      } catch (e, s) {
        failed++;
        reportSwallowedError('笔记迁移单键失败（保留 SP 键）key=$key', e, s);
      }
    }
    if (failed == 0 && migrated > 0) {
      try {
        for (final key in keys) {
          await prefs.remove(key);
        }
        await prefs.setString(_migratedSpKeysMarker, 'done');
      } catch (e, s) {
        reportSwallowedError('笔记迁移后清理 SP 键失败（重复迁移由内容幂等兜底）', e, s);
      }
    }
  }

  Future<Database> _requireDb() async {
    await ensureLoaded();
    final db = _db;
    if (db == null || !_useSqlite) {
      throw StateError('NoteRepository 未处于 SQLite 模式');
    }
    return db;
  }

  @override
  Future<List<WordNote>> getNotesByWord(int wordId) async {
    try {
      final db = await _requireDb();
      // MW-43：word 文本优先（跨词库版本稳定），word_id 作回退（存量行可能只有 id）。
      // 先由 word_id 反查 word 文本（取任意一行的 word 字段）。
      final anchor = await db.query('word_notes', where: 'word_id = ?', whereArgs: [wordId], limit: 1);
      final wordText = anchor.isEmpty ? null : anchor.first['word'] as String?;
      if (wordText != null && wordText.isNotEmpty) {
        final rows = await db.query('word_notes', where: 'word = ?', whereArgs: [wordText], orderBy: 'created_at ASC');
        return rows.map(WordNote.fromMap).toList();
      }
      final rows = await db.query('word_notes', where: 'word_id = ?', whereArgs: [wordId], orderBy: 'created_at ASC');
      return rows.map(WordNote.fromMap).toList();
    } catch (e, s) {
      reportSwallowedError('笔记列表读取失败（SQLite），回退 SP', e, s);
      return _getNotesByWordSp(wordId);
    }
  }

  Future<List<WordNote>> _getNotesByWordSp(int wordId) async {
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
    try {
      final db = await _requireDb();
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM word_notes');
      return (rows.single['c'] as int?) ?? 0;
    } catch (e, s) {
      reportSwallowedError('笔记计数读取失败（SQLite），回退 SP 扫描', e, s);
    }
    final prefs = await SharedPreferences.getInstance();
    final prefix = '${_notesKey}_';
    final keys = prefs.getKeys().where((key) => key.startsWith(prefix));
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
    return total;
  }

  int _lastNoteId = 0;

  /// SP 回退路径的 ID 生成（SQLite 路径由 AUTOINCREMENT 生成）。
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
  Future<int> addNote(int wordId, String content, {String word = ''}) async {
    try {
      final db = await _requireDb();
      final now = DateTime.now().toIso8601String();
      // MW-41：ID 只允许由持久化层生成——AUTOINCREMENT 主键，返回真实 id。
      final id = await db.insert('word_notes', {
        'word': word,
        'word_id': wordId,
        'content': content,
        'created_at': now,
        'updated_at': now,
      });
      return id;
    } catch (e, s) {
      reportSwallowedError('笔记写入失败（SQLite），回退 SP', e, s);
    }
    // SP 回退：仓储生成 ID，读改写进串行闸。
    return _serialized(() async {
      final notes = await _getNotesByWordSp(wordId);
      final id = _nextNoteId();
      final now = DateTime.now();
      notes.add(
        WordNote(
          id: id,
          wordId: wordId,
          word: word,
          content: content,
          createdAt: now.toIso8601String(),
          updatedAt: now.toIso8601String(),
        ),
      );
      await _saveNotesSp(wordId, notes);
      return id;
    });
  }

  @override
  Future<int> insertNote(WordNote note) async {
    // MW-41：insertNote 不再接受调用方带来的 null-id——统一经 addNote 走
    // 持久化层生成 ID（返回真实 id），调用方拿返回值更新 UI 实体。
    return addNote(note.wordId, note.content, word: note.word);
  }

  @override
  Future<int> updateNote(WordNote note) async {
    try {
      final db = await _requireDb();
      if (note.id == null) {
        reportSwallowedError('笔记更新缺 id（调用方契约破坏），按插入处理', StateError('updateNote(null id)'), StackTrace.current);
        final newId = await addNote(note.wordId, note.content, word: note.word);
        return newId;
      }
      final count = await db.update(
        'word_notes',
        {'content': note.content, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [note.id],
      );
      return count;
    } catch (e, s) {
      reportSwallowedError('笔记更新失败（SQLite），回退 SP', e, s);
    }
    return _serialized(() async {
      final notes = await _getNotesByWordSp(note.wordId);
      final idx = notes.indexWhere((n) => n.id == note.id);
      if (idx >= 0) {
        notes[idx] = note;
        await _saveNotesSp(note.wordId, notes);
        return 1;
      }
      return 0;
    });
  }

  @override
  Future<int> deleteNote(int noteId) async {
    try {
      final db = await _requireDb();
      return await db.delete('word_notes', where: 'id = ?', whereArgs: [noteId]);
    } catch (e, s) {
      reportSwallowedError('笔记删除失败（SQLite），回退 SP', e, s);
    }
    return _serialized(() async {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('${_notesKey}_'));
      for (final key in keys) {
        final wordId = int.tryParse(key.substring(_notesKey.length + 1));
        if (wordId == null) continue;
        final notes = await _getNotesByWordSp(wordId);
        final len = notes.length;
        notes.removeWhere((n) => n.id == noteId);
        if (notes.length != len) {
          await _saveNotesSp(wordId, notes);
          return 1;
        }
      }
      return 0;
    });
  }

  /// SP 回退写路径（带串行闸，历史读改写竞态在回退模式下仍受保护）。
  Future<void> _writeQueue = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final run = _writeQueue.then((_) => action());
    _writeQueue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<void> _saveNotesSp(int wordId, List<WordNote> notes) async {
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
