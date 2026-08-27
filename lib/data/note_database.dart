// 单词笔记数据库
// 独立于词库数据库，存储用户的个人笔记
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/word_note.dart';

/// 笔记数据库管理器（单例）
class NoteDatabase {
  static final NoteDatabase instance = NoteDatabase._();
  NoteDatabase._();

  Database? _db;
  bool _initialized = false;

  Database get db {
    if (_db == null) {
      throw StateError('笔记数据库尚未初始化，请先调用 initialize()');
    }
    return _db!;
  }

  /// 初始化笔记数据库
  Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'notes.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE word_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL,
            word TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_word_notes_word_id ON word_notes(word_id)');
      },
    );
    _initialized = true;
  }

  /// 获取单词的所有笔记
  Future<List<WordNote>> getNotesByWordId(int wordId) async {
    final rows = await db.query('word_notes', where: 'word_id = ?', whereArgs: [wordId], orderBy: 'updated_at DESC');
    return rows.map(WordNote.fromMap).toList();
  }

  /// 获取单词笔记数量
  Future<int> getNoteCount(int wordId) async {
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM word_notes WHERE word_id = ?', [wordId]);
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// 添加笔记
  Future<WordNote> insertNote(WordNote note) async {
    final id = await db.insert('word_notes', note.toMap());
    return note.copyWith(id: id);
  }

  /// 更新笔记
  Future<void> updateNote(WordNote note) async {
    await db.update('word_notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  /// 删除笔记
  Future<void> deleteNote(int noteId) async {
    await db.delete('word_notes', where: 'id = ?', whereArgs: [noteId]);
  }

  /// 获取所有笔记（按更新时间倒序）
  Future<List<WordNote>> getAllNotes({int limit = 100, int offset = 0}) async {
    final rows = await db.query('word_notes', orderBy: 'updated_at DESC', limit: limit, offset: offset);
    return rows.map(WordNote.fromMap).toList();
  }

  /// 搜索笔记内容
  Future<List<WordNote>> searchNotes(String keyword, {int limit = 50}) async {
    final rows = await db.query(
      'word_notes',
      where: 'content LIKE ? OR word LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows.map(WordNote.fromMap).toList();
  }
}
