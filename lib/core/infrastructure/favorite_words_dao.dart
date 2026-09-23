// MEM/U6：单词收藏数据访问层。
//
// SQLite（user_data.db.favorite_words，单词文本主键）为事实来源；内存 Set
// 仅作同步读（isFavorite/favoriteCount）的索引缓存，不再整表 jsonEncode 重写。
// FLUTTER_TEST 未注入数据库、或开库失败时，回退旧 SP（favorite_words_v1）
// 行为；SP 键永久保留为回滚快照，迁移幂等（marker + INSERT OR IGNORE）。
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

class FavoriteWordsDao {
  FavoriteWordsDao({Future<Database> Function()? openDatabase}) : _openOverride = openDatabase;

  static final FavoriteWordsDao instance = FavoriteWordsDao._();

  FavoriteWordsDao._() : _openOverride = null;

  static const String _spKey = 'favorite_words_v1';
  static const String _migratedMarker = 'favorite_words_sqlite_migrated_v1';

  /// 测试注入口：提供即强制 SQLite 模式（绕过 FLUTTER_TEST 探测）。
  final Future<Database> Function()? _openOverride;

  Database? _db;
  Set<String> _index = <String>{};
  Future<void>? _loading;
  bool _useSqlite = false;

  bool get usesSqlite => _useSqlite;

  /// 首次访问时加载索引并完成 SP → SQLite 迁移（幂等，单事务）。
  Future<void> ensureLoaded() => _loading ??= _ensureLoadedInner();

  Future<void> _ensureLoadedInner() async {
    final override = _openOverride;
    if (override != null) {
      try {
        final db = await override();
        await _migrateFromSpIfNeeded(db);
        final rows = await db.query('favorite_words', orderBy: 'created_at DESC');
        _db = db;
        _index = {for (final row in rows) row['word']! as String};
        _useSqlite = true;
        return;
      } catch (e, s) {
        reportSwallowedError('FavoriteWordsDao sqlite init', e, s);
      }
    } else if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        await UserDatabase.instance.initialize();
        final db = UserDatabase.instance.db;
        await _migrateFromSpIfNeeded(db);
        final rows = await db.query('favorite_words', orderBy: 'created_at DESC');
        _db = db;
        _index = {for (final row in rows) row['word']! as String};
        _useSqlite = true;
        return;
      } catch (e, s) {
        reportSwallowedError('FavoriteWordsDao sqlite init', e, s);
      }
    }
    // SP 回退：测试环境（未注入）/开库失败，保持迁移前的旧行为
    _index = (await _spPrefs()).getStringList(_spKey)?.toSet() ?? <String>{};
    _useSqlite = false;
  }

  /// SP → SQLite 首启迁移：单事务 + 行数校验，SP 快照保留不删。
  Future<void> _migrateFromSpIfNeeded(Database db) async {
    final prefs = await _spPrefs();
    if (prefs.getString(_migratedMarker) == 'done') return;

    final legacy = prefs.getStringList(_spKey) ?? const <String>[];
    if (legacy.isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      var inserted = 0;
      await db.transaction((txn) async {
        // 倒序插入：最早收藏的词得到最早的 created_at，时间倒序展示保持旧序
        for (var i = legacy.length - 1; i >= 0; i--) {
          final rowId = await txn.insert('favorite_words', {
            'word': legacy[i],
            'created_at': now - i,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          if (rowId != 0) inserted++;
        }
        if (inserted != legacy.toSet().length) {
          throw StateError('收藏词迁移行数校验失败：预期 ${legacy.toSet().length}，实际 $inserted');
        }
      });
    }
    await prefs.setString(_migratedMarker, 'done');
  }

  // ── 同步读（索引缓存口径） ──────────────────────────────────────────────

  bool isFavorite(String word) => _index.contains(word);

  int get favoriteCount => _index.length;

  Set<String> getWords() => Set<String>.of(_index);

  // ── 写路径（索引先行 + 单行持久化，O(1)） ─────────────────────────────

  Future<void> add(String word) async {
    await ensureLoaded();
    if (!_index.add(word)) return;
    await _persistAdd(word);
  }

  Future<void> remove(String word) async {
    await ensureLoaded();
    if (!_index.remove(word)) return;
    await _persistRemove(word);
  }

  /// 返回 true 表示收藏、false 表示取消收藏。
  Future<bool> toggle(String word) async {
    await ensureLoaded();
    if (!_index.contains(word)) {
      await add(word);
      return true;
    }
    await remove(word);
    return false;
  }

  Future<void> _persistAdd(String word) async {
    final db = _db;
    if (_useSqlite && db != null) {
      try {
        await db.insert('favorite_words', {
          'word': word,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (e, s) {
        reportSwallowedError('FavoriteWordsDao add persist', e, s);
      }
      return;
    }
    await _saveSp();
  }

  Future<void> _persistRemove(String word) async {
    final db = _db;
    if (_useSqlite && db != null) {
      try {
        await db.delete('favorite_words', where: 'word = ?', whereArgs: [word]);
      } catch (e, s) {
        reportSwallowedError('FavoriteWordsDao remove persist', e, s);
      }
      return;
    }
    await _saveSp();
  }

  // ── SP 回退持久化 ────────────────────────────────────────────────────────

  Future<SharedPreferences> _spPrefs() => SharedPreferences.getInstance();

  Future<void> _saveSp() async {
    try {
      await (await _spPrefs()).setStringList(_spKey, _index.toList());
    } catch (e, s) {
      reportSwallowedError('FavoriteWordsDao sp persist', e, s);
    }
  }
}
