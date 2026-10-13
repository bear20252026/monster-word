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

import 'package:word_app/core/infrastructure/degraded_journal.dart';
import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

class FavoriteWordsDao {
  FavoriteWordsDao({Future<Database> Function()? openDatabase}) : _openOverride = openDatabase;

  static final FavoriteWordsDao instance = FavoriteWordsDao._();

  FavoriteWordsDao._() : _openOverride = null;

  static const String _spKey = 'favorite_words_v1';
  static const String _migratedMarker = 'favorite_words_sqlite_migrated_v1';

  /// P1-01 余项：SQLite 写失败时的收藏意图降级日志（复用 FSRS journal 模式）。
  /// 幂等键即单词文本（favorite_words 主键），回放用 INSERT OR IGNORE / DELETE，
  /// 重复回放无副作用。
  static const String degradedJournalKey = 'favorite_words_degraded_journal_v1';
  final DegradedJournal _journal = const DegradedJournal(key: degradedJournalKey, domain: '单词收藏');

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
        reportSwallowedError('FavoriteWordsDao sqlite init', e, s);
      }
    } else if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        await UserDatabase.instance.initialize();
        final db = UserDatabase.instance.db;
        await _activateSqlite(db);
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
      final legacySet = legacy.toSet();
      // 数据层审计 P2-2：迁移事务提交与 marker 写入之间崩溃的自愈——
      // 下次启动 DB 已有全部行而 marker 仍在，INSERT OR IGNORE 会让
      // inserted=0 ≠ 预期而抛错 → 整库降级 SP 且每次启动重复失败。
      // 先查 DB 已含的 legacy 词数，已含全集即直接补写 marker。
      final placeholders = List.filled(legacySet.length, '?').join(',');
      final existing = await db.query(
        'favorite_words',
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
        // 倒序插入：最早收藏的词得到最早的 created_at，时间倒序展示保持旧序
        for (var i = legacy.length - 1; i >= 0; i--) {
          final rowId = await txn.insert('favorite_words', {
            'word': legacy[i],
            'created_at': now - i,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          if (rowId != 0) inserted++;
        }
        // 校验口径：本次新插 + 迁移前已存在 ≥ SP 去重数（崩溃自愈后重放）。
        if (inserted + existing.length < legacySet.length) {
          throw StateError('收藏词迁移行数校验失败：预期 ${legacySet.length}，实际 ${inserted + existing.length}');
        }
      });
    }
    await prefs.setString(_migratedMarker, 'done');
  }

  /// SQLite 就绪激活：迁移 → 回放降级日志 → 建内存索引。
  ///
  /// P1-01 余项：回放必须在建索引**之前**——否则降级期间（SQLite 写失败）
  /// 产生的收藏要等到下一次启动才在内存索引中可见，而本函数正是「本次启动」
  /// 的唯一入口。
  Future<void> _activateSqlite(Database db) async {
    await _migrateFromSpIfNeeded(db);
    _db = db;
    _useSqlite = true;
    await _replayDegradedJournal();
    final rows = await db.query('favorite_words', orderBy: 'created_at DESC');
    _index = {for (final row in rows) row['word']! as String};
  }

  /// 回放降级日志：add → INSERT OR IGNORE（词为主键，天然幂等）；
  /// remove → DELETE（重复删除无副作用）。回放内部任何一条失败即整体保留，
  /// 下次启动重试（DegradedJournal 口径）。
  Future<void> _replayDegradedJournal() async {
    final db = _db;
    if (db == null) return;
    await _journal.replay((entry) async {
      final word = entry['word'] as String?;
      if (word == null || word.isEmpty) return;
      final op = entry['op'] as String?;
      if (op == 'remove') {
        await db.delete('favorite_words', where: 'word = ?', whereArgs: [word]);
        return;
      }
      await db.insert('favorite_words', {
        'word': word,
        'created_at': (entry['at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  // ── 同步读（索引缓存口径） ──────────────────────────────────────────────

  bool isFavorite(String word) => _index.contains(word);

  int get favoriteCount => _index.length;

  Set<String> getWords() => Set<String>.of(_index);

  // ── 写路径（索引先行 + 单行持久化，O(1)） ─────────────────────────────

  /// 审计 I33：持久化写串行闸门——快速双击 toggle 时，前一次 add 的 insert
  /// 还在途、后一次 remove 的 delete 先执行，最终 DB 留下已"取消"的行而
  /// 内存索引已移除（重启后复活）。同 isolate 内 async 交错用 Future 链
  /// 串行化消灭；写是 O(1) 单行操作，排队开销可忽略。
  Future<void> _writeGate = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _writeGate.then((_) => action());
    _writeGate = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> add(String word) async {
    await ensureLoaded();
    // 审计 I33：索引变更与持久化整体进串行闸门（单独包 persist 仍有交错窗口）
    await _serialized(() async {
      if (!_index.add(word)) return;
      await _persistAdd(word);
    });
  }

  Future<void> remove(String word) async {
    await ensureLoaded();
    await _serialized(() async {
      if (!_index.remove(word)) return;
      await _persistRemove(word);
    });
  }

  /// 返回 true 表示收藏、false 表示取消收藏。
  /// 判定必须在闸内：闸外预检时两次快速双击都会看到「未收藏」而走 add，终态停在已收藏而非切回。
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
        await db.insert('favorite_words', {
          'word': word,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (e, s) {
        reportSwallowedError('FavoriteWordsDao add persist', e, s);
        // P1-01 余项：先落降级日志。日志写入成功则内存**不回滚**——重启后
        // 回放补上，用户这一次收藏不丢；只有连日志都写不进（磁盘满/SP 不可用）
        // 才回滚内存按硬失败处理，保留 P2-3 原意：绝不出现「界面说成功、
        // 重启后消失」的分叉。
        final journaled = await _journal.append({
          'op': 'add',
          'word': word,
          'at': DateTime.now().millisecondsSinceEpoch,
        });
        if (!journaled) {
          _index.remove(word);
          // R2-12：DB + 降级日志**双失败** = 硬失败，必须外抛。此前只回滚索引
          // 就正常返回，`toggle` 于是仍返回 true ⇒「调用方以为收藏成功，实际
          // isFavorite == false」。上层 LearningFavoritesState.toggle 本就带
          // catch（其注释即写明「写库失败在此接住并上报，返回持久层未变的旧
          // 状态」），故外抛正是该契约期待的行为。
          throw StateError('收藏写入失败且降级日志不可用（DB + journal 双失败）：$word');
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
        await db.delete('favorite_words', where: 'word = ?', whereArgs: [word]);
      } catch (e, s) {
        reportSwallowedError('FavoriteWordsDao remove persist', e, s);
        // 同 _persistAdd：日志保底成功则内存不回滚（否则取消收藏重启后复活）。
        final journaled = await _journal.append({
          'op': 'remove',
          'word': word,
          'at': DateTime.now().millisecondsSinceEpoch,
        });
        if (!journaled) {
          _index.add(word);
          // R2-12：同 _persistAdd——双失败必须外抛，不能回滚索引后静默返回成功。
          throw StateError('取消收藏失败且降级日志不可用（DB + journal 双失败）：$word');
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
      reportSwallowedError('FavoriteWordsDao sp persist', e, s);
    }
  }
}
