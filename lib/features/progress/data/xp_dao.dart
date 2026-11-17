import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/progress/application/xp_repository.dart';

/// `xp_state` 单行表访问层（M3 / schema v9）。
///
/// 幂等靠既有的 `reward_events.event_key` 主键：事件键插入与 XP 累加在**同一事务**
/// 里，重复结算只会命中主键冲突、不会再加一次经验（与发币同一条口径）。
///
/// 与任务 DAO 同惯例：FLUTTER_TEST 未注入数据库或开库失败时回退进程内累计
///（XP 属于可重建的派生数据，单测不依赖真实库；回退路径同样按事件键去重）。
class XpDao implements XpRepository {
  XpDao({Future<Database> Function()? openDatabase}) : _openOverride = openDatabase;

  static final XpDao instance = XpDao._();

  XpDao._() : _openOverride = null {
    // 第四轮审计 M18（2026-11-17）：订阅库关闭失效广播（账本同款家法）。
    UserDatabase.instance.addCloseListener(invalidate);
  }

  static const String _table = 'xp_state';
  static const String _eventTable = 'reward_events';

  /// 进程内回退的事件键上限：只需覆盖「同一次结算被重复触发」的窗口。
  static const int _memoryKeyCap = 200;

  final Future<Database> Function()? _openOverride;

  Database? _db;
  Future<void>? _loading;
  bool _useSqlite = false;
  int _memoryTotal = 0;
  final Set<String> _memoryKeys = <String>{};

  bool get usesSqlite => _useSqlite;

  void invalidate() {
    _db = null;
    _loading = null;
    _useSqlite = false;
    // M18：内存回退累计与事件键一并作废——备份恢复后旧内存值会盖住恢复库
    // 的真实 XP，且旧事件键会误判「已结算」吞掉恢复后的新结算。
    _memoryTotal = 0;
    _memoryKeys.clear();
  }

  Future<void> ensureLoaded() {
    final current = _loading;
    if (current != null) return current;
    return _loading = _ensureLoadedInner();
  }

  Future<void> _ensureLoadedInner() async {
    final override = _openOverride;
    if (override != null) {
      try {
        _db = await override();
        _useSqlite = true;
        return;
      } catch (e, s) {
        reportSwallowedError('XpDao sqlite init', e, s);
      }
    } else if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        await UserDatabase.instance.initialize();
        _db = UserDatabase.instance.db;
        _useSqlite = true;
        return;
      } catch (e, s) {
        reportSwallowedError('XpDao sqlite init', e, s);
      }
    }
    _useSqlite = false;
  }

  @override
  Future<int> loadTotalXp() async {
    await ensureLoaded();
    if (_useSqlite && _db != null) {
      try {
        final rows = await _db!.query(_table, where: 'id = 1');
        _memoryTotal = rows.isEmpty ? 0 : ((rows.first['total_xp'] as int?) ?? 0);
        return _memoryTotal;
      } catch (e, s) {
        // 第三轮 T15：与 A6 写路径同口径——瞬态读失败只本次回退内存缓存值，
        // 不置粘性降级（旧实现一次读竞态即永久 _useSqlite=false，XP 重启归零）。
        reportSwallowedError('XpDao 读取失败，本次回退内存（下次读写重试 SQLite）', e, s);
      }
    }
    return _memoryTotal;
  }

  @override
  Future<int?> addXpOnce({required String eventKey, required int delta}) async {
    if (delta <= 0) return null;
    await ensureLoaded();
    if (!_useSqlite || _db == null) return _addInMemory(eventKey, delta);
    try {
      final newTotal = await _db!.transaction((txn) async {
        await txn.insert(_eventTable, {'event_key': eventKey, 'created_at': DateTime.now().millisecondsSinceEpoch});
        final rows = await txn.query(_table, where: 'id = 1');
        final total = rows.isEmpty ? 0 : ((rows.first['total_xp'] as int?) ?? 0);
        final next = total + delta;
        if (rows.isEmpty) {
          await txn.insert(_table, {'id': 1, 'total_xp': next});
        } else {
          await txn.update(_table, {'total_xp': next}, where: 'id = 1');
        }
        return next;
      });
      _memoryTotal = newTotal;
      return newTotal;
    } on DatabaseException catch (e) {
      // 主键冲突 = 这一局的 XP 已经发过；事务已回滚，累计 XP 不变。
      if (e.isUniqueConstraintError()) return null;
      // 审计 A6（2026-11-15）：瞬态写失败只本次回退内存，不粘性降级——
      // 下次 addXpOnce 仍试 SQLite，避免 DB 抖动后 XP 永久只存内存、重启归零。
      reportSwallowedError('XpDao 写入失败，本次回退内存（下次写入重试 SQLite）', e, StackTrace.current);
      return _addInMemory(eventKey, delta);
    } catch (e, s) {
      reportSwallowedError('XpDao 写入失败，本次回退内存（下次写入重试 SQLite）', e, s);
      return _addInMemory(eventKey, delta);
    }
  }

  int? _addInMemory(String eventKey, int delta) {
    if (_memoryKeys.contains(eventKey)) return null;
    _memoryKeys.add(eventKey);
    if (_memoryKeys.length > _memoryKeyCap) _memoryKeys.remove(_memoryKeys.first);
    _memoryTotal += delta;
    return _memoryTotal;
  }
}
