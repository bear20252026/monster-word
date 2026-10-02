// P0-4（性能审计 I18）：尖叫币账本数据访问层。
//
// SQLite（user_data.db.scare_coin_entries + scare_coin_meta）为事实来源：
// 每答对一次从「全量 200 条 JSON 读改写」降为单行 INSERT + 余额 KV 单行
// UPSERT（同一事务）。FLUTTER_TEST 未注入数据库、或开库失败时回退旧 SP
// （scare_coin.history / scare_coin.balance）行为；SP 键永久保留为回滚
// 快照，迁移幂等（HouseStyle 同 FavoriteWordsDao，迁移标记放 DB 内 meta
// 表、与入账同一事务——流水无天然唯一键，SP 标记的「事务已提交、标记
// 未写」崩溃窗口在这里会重复记账，不可接受）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/models/scare_coin_entry.dart';

class ScareCoinLedgerDao {
  /// 测试注入口：提供即强制 SQLite 模式（绕过 FLUTTER_TEST 探测）。
  ScareCoinLedgerDao({Future<Database> Function()? openDatabase}) : _openOverride = openDatabase;

  static final ScareCoinLedgerDao instance = ScareCoinLedgerDao._();

  ScareCoinLedgerDao._() : _openOverride = null;

  static const String _spHistoryKey = 'scare_coin.history';
  static const String _spBalanceKey = 'scare_coin.balance';

  static const String _entriesTable = 'scare_coin_entries';
  static const String _metaTable = 'scare_coin_meta';
  static const String _kBalance = 'balance';
  static const String _kMigratedFromSp = 'migrated_from_sp';

  /// 展示截断口径与旧 200 条 JSON 截断一致（写侧不再截断，追加廉价）。
  static const int historyLimit = 200;

  final Future<Database> Function()? _openOverride;

  Database? _db;
  Future<void>? _loading;
  bool _useSqlite = false;

  bool get usesSqlite => _useSqlite;

  /// P2-2：UserDatabase.close() 只复位自身、不通知本 DAO——close 后若不清
  /// 缓存，DAO 永久卡「假 SQLite 模式」（_db 句柄已关闭但 _useSqlite 仍为
  /// true，操作抛 database_closed，且 ensureLoaded 命中缓存的 completed
  /// future 永不重载）。失败操作路径经 [_runGuarded] 自动失效；外部
  /// 主动关闭库（测试/未来生命周期管理）也可显式调用。
  void invalidate() {
    _db = null;
    _loading = null;
    _useSqlite = false;
  }

  /// 首次访问时完成 SP → SQLite 迁移（幂等，单事务）。
  /// 失效（[invalidate]）后重新走 [_ensureLoadedInner]，重取新库句柄。
  Future<void> ensureLoaded() {
    final current = _loading;
    if (current != null) return current;
    return _loading = _ensureLoadedInner();
  }

  Future<void> _ensureLoadedInner() async {
    final override = _openOverride;
    if (override != null) {
      try {
        final db = await override();
        await _migrateFromSpIfNeeded(db);
        _db = db;
        _useSqlite = true;
        return;
      } catch (e, s) {
        reportSwallowedError('ScareCoinLedgerDao sqlite init', e, s);
      }
    } else if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        await UserDatabase.instance.initialize();
        final db = UserDatabase.instance.db;
        await _migrateFromSpIfNeeded(db);
        _db = db;
        _useSqlite = true;
        return;
      } catch (e, s) {
        reportSwallowedError('ScareCoinLedgerDao sqlite init', e, s);
      }
    }
    // SP 回退：测试环境（未注入）/开库失败，保持迁移前的旧行为
    _useSqlite = false;
  }

  /// SP → SQLite 首启迁移：余额 + 既有流水单事务入表，SP 快照保留不删。
  ///
  /// 账本 JSON 损坏时只丢「存量流水」并上报，余额照迁、不阻断 SQLite 启用
  /// （与运行期「宁丢一条新账不清原账本」同口径——旧账留在 SP 快照里不丢）。
  /// 库文件损坏被删重建后标记行随库消失，会从 SP 快照重放一次迁移：
  /// 余额回退到迁移前快照值，属既定取舍（与收藏 DAO 回滚快照同语义）。
  Future<void> _migrateFromSpIfNeeded(Database db) async {
    final marked = await db.query(_metaTable, where: 'key = ?', whereArgs: [_kMigratedFromSp]);
    if (marked.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final legacyBalance = prefs.getInt(_spBalanceKey);
    List<ScareCoinEntry>? legacyEntries;
    try {
      final raw = prefs.getString(_spHistoryKey);
      if (raw != null && raw.isNotEmpty) {
        legacyEntries = (jsonDecode(raw) as List)
            .map((entry) => ScareCoinEntry.fromJson(entry as Map<String, dynamic>))
            .toList();
      }
    } catch (e, s) {
      reportSwallowedError('尖叫币账本迁移：SP 流水解析失败，余额照迁、流水从零起账（SP 快照保留）', e, s);
    }

    await db.transaction((txn) async {
      if (legacyBalance != null) {
        await txn.insert(_metaTable, {
          'key': _kBalance,
          'value': legacyBalance,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (legacyEntries != null) {
        // SP 里 index 0 是最新一条：倒序插入使 id 正序与时间序一致，
        // 同毫秒流水的「按插入序倒序」展示与旧列表排序口径相同。
        for (var i = legacyEntries.length - 1; i >= 0; i--) {
          await txn.insert(_entriesTable, _entryRow(legacyEntries[i]));
        }
      }
      // 迁移标记与数据同事务落库：要么全有要么全无，重放不会重复入账
      await txn.insert(_metaTable, {'key': _kMigratedFromSp, 'value': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  Future<int> balance() {
    return _runGuarded<int>((db) async {
      final rows = await db.query(_metaTable, where: 'key = ?', whereArgs: [_kBalance]);
      return rows.isEmpty ? 0 : rows.first['value']! as int;
    });
  }

  /// 余额变动 + 流水追加，同一事务；负余额抛 StateError 且整体回滚
  /// （余额与流水都不落库，与旧 SP 路径的负余额守卫语义一致）。
  Future<int> applyDelta({required int delta, required ScareCoinEntry entry}) {
    return _runGuarded<int>((db) {
      return db.transaction<int>((txn) async {
        final rows = await txn.query(_metaTable, where: 'key = ?', whereArgs: [_kBalance]);
        final current = rows.isEmpty ? 0 : rows.first['value']! as int;
        final next = current + delta;
        if (next < 0) {
          throw StateError('余额不足：current=$current, delta=$delta');
        }
        await txn.insert(_metaTable, {'key': _kBalance, 'value': next}, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.insert(_entriesTable, _entryRow(entry));
        return next;
      });
    });
  }

  /// 零变动流水（发卡/续命审计），追加不截断。
  Future<void> appendEntry(ScareCoinEntry entry) {
    return _runGuarded<void>((db) => db.insert(_entriesTable, _entryRow(entry)));
  }

  /// 最新 [limit] 条流水，时间倒序（同毫秒按插入序倒序），与旧排序口径一致。
  Future<List<ScareCoinEntry>> history({int limit = historyLimit}) {
    return _runGuarded<List<ScareCoinEntry>>((db) async {
      final rows = await db.query(_entriesTable, orderBy: 'time_ms DESC, id DESC', limit: limit);
      return rows
          .map(
            (row) => ScareCoinEntry(
              time: DateTime.fromMillisecondsSinceEpoch(row['time_ms']! as int),
              delta: row['delta']! as int,
              reason: row['reason']! as String,
            ),
          )
          .toList();
    });
  }

  Database _requireDb() {
    final db = _db;
    if (db == null || !_useSqlite) {
      throw StateError('ScareCoinLedgerDao 未处于 SQLite 模式，请先 ensureLoaded()');
    }
    return db;
  }

  /// P2-2：统一操作包装。底层库被 UserDatabase.close() 等外部 close 后，
  /// sqflite（sqflite_common_ffi 同源）在已关闭句柄上的操作抛
  /// DatabaseException('error database_closed')，包内公开判定为
  /// [DatabaseException.isDatabaseClosedError]。命中即自动失效并原样
  /// rethrow——不回退 SP 语义：唯一生产调用方 PreferencesScareCoinStore
  /// 的 balance/history 本就直接透传 DAO 异常（_apply 的负余额也照抛），
  /// 而 SP 快照只反映迁移前状态、close 前的新账不在其中，假装成功会静默
  /// 丢单条账目。失效后下次 ensureLoaded()（store._sqliteLedger 每次操作
  /// 都会先调）重走 _ensureLoadedInner 拿新句柄，恢复 SQLite 模式。
  Future<T> _runGuarded<T>(Future<T> Function(Database db) action) async {
    final db = _requireDb();
    try {
      return await action(db);
    } on DatabaseException catch (e) {
      if (e.isDatabaseClosedError()) {
        reportSwallowedError('金币账本数据库连接已失效，重置为可重载状态', e, StackTrace.current);
        invalidate();
      }
      rethrow;
    }
  }

  Map<String, Object> _entryRow(ScareCoinEntry entry) => {
    'time_ms': entry.time.millisecondsSinceEpoch,
    'delta': entry.delta,
    'reason': entry.reason,
  };
}

// 数据层审计 P2-2：UserDatabase.close()（user_database.dart）复位自身但不
// 通知本 DAO。失效机制两条路：① 外部关闭后显式 invalidate()；② 已关闭
// 句柄上的操作抛 database_closed 类异常时 _runGuarded 自动失效并上报。
// 失效后 ensureLoaded() 重新加载，不会永久卡死在假 SQLite 模式。
// 注意：不给 UserDatabase 加 DAO 通知（避免 infrastructure 内反向依赖环）。
