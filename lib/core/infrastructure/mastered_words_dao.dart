// P2-10（架构审计 2026-11-12）：掌握词表数据访问层。
//
// SQLite（user_data.db.mastered_words，单词文本主键）为事实来源；内存 Set
// 仅作同步读（isMastered/masteredCount）的索引缓存，不再整表 setStringList 重写。
// FLUTTER_TEST 未注入数据库、或开库失败时，回退旧 SP（mastered_words_v1）
// 行为；SP 键永久保留为回滚快照，迁移幂等（marker + INSERT OR IGNORE）。
// 口径完全对齐 FavoriteWordsDao（收藏先例）。
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/infrastructure/degraded_journal.dart';
import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

class MasteredWordsDao {
  MasteredWordsDao({Future<Database> Function()? openDatabase}) : _openOverride = openDatabase;

  static final MasteredWordsDao instance = MasteredWordsDao._();

  MasteredWordsDao._() : _openOverride = null;

  static const String _spKey = 'mastered_words_v1';
  static const String _migratedMarker = 'mastered_words_sqlite_migrated_v1';

  /// SQLite 写失败时的掌握意图降级日志（复用收藏/FSRS journal 模式）。
  /// 幂等键即单词文本（mastered_words 主键），回放用 INSERT OR IGNORE / DELETE，
  /// 重复回放无副作用。
  static const String degradedJournalKey = 'mastered_words_degraded_journal_v1';
  final DegradedJournal _journal = const DegradedJournal(key: degradedJournalKey, domain: '掌握词表');

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
        await _activateSqlite(db);
        return;
      } catch (e, s) {
        reportSwallowedError('MasteredWordsDao sqlite init', e, s);
      }
    } else if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        await UserDatabase.instance.initialize();
        final db = UserDatabase.instance.db;
        await _activateSqlite(db);
        return;
      } catch (e, s) {
        reportSwallowedError('MasteredWordsDao sqlite init', e, s);
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
      final legacySet = legacy.toSet();
      // 迁移事务提交与 marker 写入之间崩溃的自愈（同收藏先例）：
      // 下次启动 DB 已有全部行而 marker 仍在，INSERT OR IGNORE 会让
      // inserted=0 ≠ 预期而抛错 → 整库降级 SP 且每次启动重复失败。
      // 先查 DB 已含的 legacy 词数，已含全集即直接补写 marker。
      final placeholders = List.filled(legacySet.length, '?').join(',');
      final existing = await db.query(
        'mastered_words',
        columns: ['word'],
        where: 'word IN ($placeholders)',
        whereArgs: legacySet.toList(),
      );
      if (existing.length >= legacySet.length) {
        await prefs.setString(_migratedMarker, 'done');
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      var inserted = 0;
      await db.transaction((txn) async {
        // 倒序插入：最早掌握的词得到最早的 created_at，时间序保持旧序
        for (var i = legacy.length - 1; i >= 0; i--) {
          final rowId = await txn.insert('mastered_words', {
            'word': legacy[i],
            'created_at': now - i,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          if (rowId != 0) inserted++;
        }
        // 校验口径：本次新插 + 迁移前已存在 ≥ SP 去重数（崩溃自愈后重放）。
        if (inserted + existing.length < legacySet.length) {
          throw StateError('掌握词迁移行数校验失败：预期 ${legacySet.length}，实际 ${inserted + existing.length}');
        }
      });
    }
    await prefs.setString(_migratedMarker, 'done');
  }

  /// SQLite 就绪激活：迁移 → 回放降级日志 → 建内存索引。
  /// 回放必须在建索引之前（同收藏先例），否则降级期间的掌握要等下次启动才可见。
  Future<void> _activateSqlite(Database db) async {
    await _migrateFromSpIfNeeded(db);
    _db = db;
    _useSqlite = true;
    await _replayDegradedJournal();
    final rows = await db.query('mastered_words', orderBy: 'created_at DESC');
    _index = {for (final row in rows) row['word']! as String};
  }

  /// 回放降级日志：add → INSERT OR IGNORE（词为主键，天然幂等）；
  /// remove → DELETE（重复删除无副作用）。
  Future<void> _replayDegradedJournal() async {
    final db = _db;
    if (db == null) return;
    await _journal.replay((entry) async {
      final word = entry['word'] as String?;
      if (word == null || word.isEmpty) return;
      final op = entry['op'] as String?;
      if (op == 'remove') {
        await db.delete('mastered_words', where: 'word = ?', whereArgs: [word]);
        return;
      }
      await db.insert('mastered_words', {
        'word': word,
        'created_at': (entry['at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  // ── 同步读（索引缓存口径） ──────────────────────────────────────────────

  bool isMastered(String word) => _index.contains(word);

  int get masteredCount => _index.length;

  Set<String> getWords() => Set<String>.of(_index);

  // ── 写路径（索引先行 + 单行持久化，O(1)） ─────────────────────────────

  /// 持久化写串行闸门（同收藏 I33）：快速双击 toggle 时消灭 async 交错，
  /// 判定必须在闸内，否则两次双击都看到「未掌握」而走 add，终态停在已掌握。
  Future<void> _writeGate = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _writeGate.then((_) => action());
    _writeGate = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  /// 切换掌握状态：返回 true 表示掌握、false 表示取消掌握。
  Future<bool> toggle(String word) async {
    await ensureLoaded();
    return _serialized(() async {
      if (_index.contains(word)) {
        _index.remove(word);
        await _persistRemove(word);
        return false;
      }
      _index.add(word);
      await _persistAdd(word);
      return true;
    });
  }

  Future<void> _persistAdd(String word) async {
    final db = _db;
    if (_useSqlite && db != null) {
      try {
        await db.insert('mastered_words', {
          'word': word,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (e, s) {
        reportSwallowedError('MasteredWordsDao add persist', e, s);
        // 先落降级日志：成功则内存不回滚（重启回放补上）；连日志都写不进才回滚外抛。
        final journaled = await _journal.append({
          'op': 'add',
          'word': word,
          'at': DateTime.now().millisecondsSinceEpoch,
        });
        if (!journaled) {
          _index.remove(word);
          throw StateError('掌握写入失败且降级日志不可用（DB + journal 双失败）：$word');
        }
      }
      return;
    }
    await _saveSp();
  }

  Future<void> _persistRemove(String word) async {
    final db = _db;
    if (_useSqlite && db != null) {
      try {
        await db.delete('mastered_words', where: 'word = ?', whereArgs: [word]);
      } catch (e, s) {
        reportSwallowedError('MasteredWordsDao remove persist', e, s);
        final journaled = await _journal.append({
          'op': 'remove',
          'word': word,
          'at': DateTime.now().millisecondsSinceEpoch,
        });
        if (!journaled) {
          _index.add(word);
          throw StateError('取消掌握失败且降级日志不可用（DB + journal 双失败）：$word');
        }
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
      reportSwallowedError('MasteredWordsDao sp persist', e, s);
    }
  }
}
