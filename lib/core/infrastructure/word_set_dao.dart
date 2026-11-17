// 第四轮审计 M7（2026-11-17）：词汇集合 DAO 公共基类。
//
// favorite_words_dao（278 行）与 mastered_words_dao（244 行）约 95% 逐行同构
// （init/迁移/写闸/回放/persist 仅表名键名不同）。抽公共基类消重复；
// 差异面（表名/SP 键/迁移标记/降级日志键/域名/错误文案）经构造参数注入。
//
// 口径逐条保留（注释随迁自收藏先例）：
// - SQLite 事实来源 + 内存 Set 同步读索引；SP 回退保持迁移前行为；
// - 迁移单事务 + 行数校验 + 崩溃自愈（DB 已含全集直接补 marker）+
//   IN 绑定 500 分批（A4：Android≤9 SQLite 999 变量上限）；
// - 回放先于建索引（降级期写入本次启动即可见）；
// - 写串行闸（I33）：索引变更与持久化整体进闸，判定在闸内（防双击竞态）；
// - 持久化失败先落降级日志，日志成功内存不回滚；双失败回滚索引并外抛（R2-12）；
// - 库关闭广播失效（M18）：句柄/索引/加载 future 作废，下次 ensureLoaded 重建。
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/infrastructure/degraded_journal.dart';
import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

/// 词汇集合 DAO 基类（单词文本主键的 add/remove/toggle 集合）。
abstract class WordSetDao {
  WordSetDao({
    required this.tableName,
    required this.spKey,
    required this.migratedMarker,
    required String degradedJournalKey,
    required this.domainLabel,
    Future<Database> Function()? openDatabase,
    bool subscribeCloseBroadcast = true,
  }) : _openOverride = openDatabase,
       _journal = DegradedJournal(key: degradedJournalKey, domain: domainLabel) {
    // M18：订阅库关闭失效广播。测试注入实例（openDatabase 非空）不订阅：
    // 它们不消费 UserDatabase，防跨用例泄漏。
    if (subscribeCloseBroadcast && openDatabase == null) {
      UserDatabase.instance.addCloseListener(invalidate);
    }
  }

  /// SQLite 表名（单词文本主键 + created_at）。
  final String tableName;

  /// SP 回退/迁移源键。
  final String spKey;

  /// SP → SQLite 迁移完成标记键。
  final String migratedMarker;

  /// 域名（错误文案/降级日志 domain 用，如「单词收藏」「掌握词表」）。
  final String domainLabel;

  final DegradedJournal _journal;

  /// 测试注入口：提供即强制 SQLite 模式（绕过 FLUTTER_TEST 探测）。
  final Future<Database> Function()? _openOverride;

  Database? _db;
  Set<String> _index = <String>{};
  Future<void>? _loading;
  bool _useSqlite = false;

  bool get usesSqlite => _useSqlite;

  /// 作废缓存句柄与内存索引（库关闭广播 / 测试复位用）。
  void invalidate() {
    _db = null;
    _loading = null;
    _useSqlite = false;
    _index = <String>{};
  }

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
        reportSwallowedError('$domainLabel sqlite init', e, s);
      }
    } else if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        await UserDatabase.instance.initialize();
        final db = UserDatabase.instance.db;
        await _activateSqlite(db);
        return;
      } catch (e, s) {
        reportSwallowedError('$domainLabel sqlite init', e, s);
      }
    }
    // SP 回退：测试环境（未注入）/开库失败，保持迁移前的旧行为
    _index = (await _spPrefs()).getStringList(spKey)?.toSet() ?? <String>{};
    _useSqlite = false;
  }

  /// SP → SQLite 首启迁移：单事务 + 行数校验，SP 快照保留不删。
  Future<void> _migrateFromSpIfNeeded(Database db) async {
    final prefs = await _spPrefs();
    if (prefs.getString(migratedMarker) == 'done') return;

    final legacy = prefs.getStringList(spKey) ?? const <String>[];
    if (legacy.isNotEmpty) {
      final legacySet = legacy.toSet();
      // 迁移事务提交与 marker 写入之间崩溃的自愈：
      // 下次启动 DB 已有全部行而 marker 仍在，INSERT OR IGNORE 会让
      // inserted=0 ≠ 预期而抛错 → 整库降级 SP 且每次启动重复失败。
      // 先查 DB 已含的 legacy 词数，已含全集即直接补写 marker。
      // 审计 A4（2026-11-15）：IN 绑定按 500 分批，防 Android≤9 SQLite 999 变量上限。
      final legacyList = legacySet.toList();
      final existing = <Map<String, Object?>>[];
      for (var i = 0; i < legacyList.length; i += 500) {
        final batch = legacyList.sublist(i, (i + 500).clamp(0, legacyList.length));
        final placeholders = List.filled(batch.length, '?').join(',');
        existing.addAll(
          await db.query(tableName, columns: ['word'], where: 'word IN ($placeholders)', whereArgs: batch),
        );
      }
      if (existing.length >= legacySet.length) {
        await prefs.setString(migratedMarker, 'done');
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      var inserted = 0;
      await db.transaction((txn) async {
        // 倒序插入：最早加入的词得到最早的 created_at，时间倒序展示保持旧序
        for (var i = legacy.length - 1; i >= 0; i--) {
          final rowId = await txn.insert(tableName, {
            'word': legacy[i],
            'created_at': now - i,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          if (rowId != 0) inserted++;
        }
        // 校验口径：本次新插 + 迁移前已存在 ≥ SP 去重数（崩溃自愈后重放）。
        if (inserted + existing.length < legacySet.length) {
          throw StateError('$domainLabel迁移行数校验失败：预期 ${legacySet.length}，实际 ${inserted + existing.length}');
        }
      });
    }
    await prefs.setString(migratedMarker, 'done');
  }

  /// SQLite 就绪激活：迁移 → 回放降级日志 → 建内存索引。
  /// 回放必须在建索引之前，否则降级期间的写入要等下次启动才可见。
  Future<void> _activateSqlite(Database db) async {
    await _migrateFromSpIfNeeded(db);
    _db = db;
    _useSqlite = true;
    await _replayDegradedJournal();
    final rows = await db.query(tableName, orderBy: 'created_at DESC');
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
        await db.delete(tableName, where: 'word = ?', whereArgs: [word]);
        return;
      }
      await db.insert(tableName, {
        'word': word,
        'created_at': (entry['at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  // ── 同步读（索引缓存口径） ──────────────────────────────────────────────

  bool contains(String word) => _index.contains(word);

  int get count => _index.length;

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

  /// 返回 true 表示加入、false 表示移除。
  /// 判定必须在闸内：闸外预检时两次快速双击都会看到「未加入」而走 add，终态停在已加入而非切回。
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
        await db.insert(tableName, {
          'word': word,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (e, s) {
        reportSwallowedError('$domainLabel add persist', e, s);
        // P1-01 余项：先落降级日志。日志写入成功则内存**不回滚**——重启后
        // 回放补上，用户这一次操作不丢；只有连日志都写不进（磁盘满/SP 不可用）
        // 才回滚内存按硬失败处理：绝不出现「界面说成功、重启后消失」的分叉。
        final journaled = await _journal.append({
          'op': 'add',
          'word': word,
          'at': DateTime.now().millisecondsSinceEpoch,
        });
        if (!journaled) {
          _index.remove(word);
          // R2-12：DB + 降级日志**双失败** = 硬失败，必须外抛（上层 State 带
          // catch，返回持久层未变的旧状态正是该契约期待的行为）。
          throw StateError('$domainLabel写入失败且降级日志不可用（DB + journal 双失败）：$word');
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
        await db.delete(tableName, where: 'word = ?', whereArgs: [word]);
      } catch (e, s) {
        reportSwallowedError('$domainLabel remove persist', e, s);
        // 同 _persistAdd：日志保底成功则内存不回滚（否则移除操作重启后复活）。
        final journaled = await _journal.append({
          'op': 'remove',
          'word': word,
          'at': DateTime.now().millisecondsSinceEpoch,
        });
        if (!journaled) {
          _index.add(word);
          // R2-12：同 _persistAdd——双失败必须外抛，不能回滚索引后静默返回成功。
          throw StateError('取消$domainLabel失败且降级日志不可用（DB + journal 双失败）：$word');
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
      await (await _spPrefs()).setStringList(spKey, _index.toList());
    } catch (e, s) {
      reportSwallowedError('$domainLabel sp persist', e, s);
    }
  }
}
