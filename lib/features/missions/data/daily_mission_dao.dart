import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/missions/application/daily_mission_repository.dart';
import 'package:word_app/features/missions/domain/daily_mission.dart';

/// `daily_missions` 表访问层（M2 / schema v8）。
///
/// 与账本 DAO 同惯例：FLUTTER_TEST 未注入数据库、开库失败或写失败时回退
/// 进程内内存（每日任务本来就是当天数据，丢失只影响当天进度，不影响账本）。
/// SQLite 写采用「UPDATE 命中 0 行再 INSERT」两步，不用 UPSERT
///（minSdk 24 的 SQLite < 3.24，见 sqlite_compat_guard_test）。
class DailyMissionDao implements DailyMissionRepository {
  DailyMissionDao({Future<Database> Function()? openDatabase}) : _openOverride = openDatabase;

  static final DailyMissionDao instance = DailyMissionDao._();

  DailyMissionDao._() : _openOverride = null;

  static const String _table = 'daily_missions';

  final Future<Database> Function()? _openOverride;

  Database? _db;
  Future<void>? _loading;
  bool _useSqlite = false;

  /// 内存回退（测试 / 开库失败）。按天保留，跨天自然换 key。
  final Map<String, Map<DailyMissionId, DailyMissionRecord>> _memory = {};

  bool get usesSqlite => _useSqlite;

  void invalidate() {
    _db = null;
    _loading = null;
    _useSqlite = false;
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
        reportSwallowedError('DailyMissionDao sqlite init', e, s);
      }
    } else if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        await UserDatabase.instance.initialize();
        _db = UserDatabase.instance.db;
        _useSqlite = true;
        return;
      } catch (e, s) {
        reportSwallowedError('DailyMissionDao sqlite init', e, s);
      }
    }
    _useSqlite = false;
  }

  @override
  Future<Map<DailyMissionId, DailyMissionRecord>> load(String day) async {
    await ensureLoaded();
    if (_useSqlite && _db != null) {
      try {
        final rows = await _db!.query(_table, where: 'day = ?', whereArgs: [day]);
        final result = <DailyMissionId, DailyMissionRecord>{};
        for (final row in rows) {
          final id = DailyMissionId.fromKey(row['task_id']! as String);
          if (id == null) continue;
          result[id] = DailyMissionRecord(
            progress: (row['progress'] as int?) ?? 0,
            completedAt: _time(row['completed_at']),
            rewardClaimedAt: _time(row['reward_claimed_at']),
          );
        }
        return result;
      } catch (e, s) {
        // 第三轮 T15：与 A3 写路径同口径——瞬态读失败只本次回退内存，不置
        // 粘性降级（旧实现一次读竞态即永久 _useSqlite=false，当日进度重启归零）。
        // 保持 _useSqlite=true：下次 load/save 自动重试 SQLite。
        reportSwallowedError('DailyMissionDao load 失败，本次回退内存（下次读写重试 SQLite）', e, s);
      }
    }
    return Map<DailyMissionId, DailyMissionRecord>.from(_memory[day] ?? const {});
  }

  @override
  Future<void> save(String day, DailyMissionId id, DailyMissionRecord record) async {
    _memory.putIfAbsent(day, () => {})[id] = record;
    await ensureLoaded();
    if (!_useSqlite || _db == null) return;
    final values = {
      'progress': record.progress,
      'completed_at': record.completedAt?.millisecondsSinceEpoch,
      'reward_claimed_at': record.rewardClaimedAt?.millisecondsSinceEpoch,
    };
    try {
      // 审计 A3（2026-11-15）：UPDATE→INSERT 包进单事务，串行化并发同 (day,task)
      // 写入，杜绝两步之间撞主键；与 UsageStatsDao 同惯例。
      await _db!.transaction((txn) async {
        final updated = await txn.update(_table, values, where: 'day = ? AND task_id = ?', whereArgs: [day, id.key]);
        if (updated == 0) {
          await txn.insert(_table, {'day': day, 'task_id': id.key, ...values});
        }
      });
    } catch (e, s) {
      // 审计 A3：瞬态写失败只保留内存值、下次 save 重试 SQLite，不粘性降级
      // （旧实现一次竞态即永久 _useSqlite=false，当日进度重启即丢）。
      reportSwallowedError('DailyMissionDao save 失败，保留内存值（下次写入重试 SQLite）', e, s);
    }
  }

  DateTime? _time(Object? raw) {
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }
}
