// MW-06（第六阶段审计）：用户库与复习库的持续一致性备份。
//
// 背景：fsrs6_emergency_backup_v1 只保留 SP→SQLite 迁移时的历史快照，
// 不能替代「最新 FSRS/用户数据的持续备份」。本服务用 SQLite 在线备份
// 能力（VACUUM INTO）在只读连接上生成一致性快照——由 SQLite 读穿 WAL，
// 不在写入中简单复制主文件，天然规避「备份到撕裂状态」。
//
// 策略：
// - 每次冷启动异步触发（不阻塞 bootstrap），24h 节流（SP 记录上次成功时间）；
// - 覆盖 user_data.db 与 review_schedule.db，输出 <db 名>-<YYYYMMDD>.bak；
// - 第四轮审计 M3（2026-11-17）：同戳追加 SP 全量快照 sp_prefs-<YYYYMMDD>.json
//   （经 UserDataSpRegistry：凭证键排除、类型保真）。此前 SP 独有数据
//   （保护卡/兑换章/奖励队列/降级日志/怪兽羁绊…）完全不在备份内，恢复后
//   SP 与 DB 不同步；新增 SP 存储也会静默漏备。全量快照口径下新键自动覆盖。
// - 每类保留最近 3 份，超限清理最旧（先删旧、写新失败则旧仍可用）；
// - manifest.json 记录最近一次成功备份的文件与字节数，供诊断/恢复页面读取；
// - 任何失败只上报不抛出——备份是尽力而为的增值保护，绝不影响启动。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/infrastructure/user_data_sp_registry.dart';
import 'package:word_app/core/utils/debug_log.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

class UserDataBackupService {
  UserDataBackupService._();

  static const String _lastRunKey = 'user_data_backup_last_run_v1';
  static const String _manifestName = 'manifest.json';
  static const int keepCount = 3;

  /// 仅供测试注入根目录与数据库文件名（真实调用方使用默认参数）。
  @visibleForTesting
  static String? directoryOverrideForTest;

  /// 触发启动备份（fire-and-forget 调用；内部吞掉一切异常）。
  ///
  /// [minInterval] 节流窗口，默认 24h；[now] 仅供测试注入时钟。
  static Future<void> runStartupBackup({Duration minInterval = const Duration(hours: 24), DateTime? now}) async {
    try {
      final root = directoryOverrideForTest ?? (await getApplicationSupportDirectory()).path;
      final backupDir = Directory(p.join(root, 'backups'));
      if (!backupDir.existsSync()) backupDir.createSync(recursive: true);

      // 节流：距上次成功不足窗口则跳过。
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_lastRunKey) ?? 0;
      final clock = now ?? DateTime.now();
      if (lastMs > 0 && clock.millisecondsSinceEpoch - lastMs < minInterval.inMilliseconds) {
        debugLog('[Backup] 距上次备份不足 ${minInterval.inHours}h，跳过');
        return;
      }

      final backedUp = <String, int>{};
      final stamp = _dateStamp(clock);
      for (final dbName in const ['user_data.db', 'review_schedule.db']) {
        final source = File(p.join(root, dbName));
        if (!source.existsSync() || source.lengthSync() == 0) continue;
        final target = p.join(backupDir.path, '$dbName-$stamp.bak');
        try {
          await _snapshot(source.path, target);
          backedUp[target] = File(target).lengthSync();
          await _pruneOldBackups(backupDir, dbName, '.bak');
        } catch (e, s) {
          reportSwallowedError('数据备份失败（$dbName）', e, s);
        }
      }

      // M3：SP 全量快照（与 db 同戳）。失败只上报——db 备份仍有效，
      // 恢复侧对缺 SP 快照的旧备份按「仅恢复 db」降级处理（见维护服务）。
      try {
        final spTarget = p.join(backupDir.path, 'sp_prefs-$stamp.json');
        await _snapshotSp(spTarget);
        backedUp[spTarget] = File(spTarget).lengthSync();
        await _pruneOldBackups(backupDir, 'sp_prefs', '.json');
      } catch (e, s) {
        reportSwallowedError('SP 偏好快照备份失败（db 备份不受影响）', e, s);
      }

      if (backedUp.isNotEmpty) {
        await _writeManifest(backupDir, clock, backedUp);
        await prefs.setInt(_lastRunKey, clock.millisecondsSinceEpoch);
        debugLog('[Backup] 完成 ${backedUp.length} 个库的一致性快照');
      }
    } catch (e, s) {
      reportSwallowedError('数据备份服务执行失败', e, s);
    }
  }

  /// 列出当前可用备份（恢复/诊断页面用），新→旧排列。
  static Future<List<Map<String, Object?>>> listBackups() async {
    try {
      final root = directoryOverrideForTest ?? (await getApplicationSupportDirectory()).path;
      final backupDir = Directory(p.join(root, 'backups'));
      if (!backupDir.existsSync()) return const [];
      final entries = <Map<String, Object?>>[];
      for (final f in backupDir.listSync().whereType<File>()) {
        // M3：SP 快照（sp_prefs-*.json）也是备份件，纳入列表供诊断页展示。
        final name = p.basename(f.path);
        final isSpSnapshot = name.startsWith('sp_prefs-') && name.endsWith('.json');
        if (!f.path.endsWith('.bak') && !isSpSnapshot && name != _manifestName) continue;
        entries.add({
          'name': p.basename(f.path),
          'bytes': f.existsSync() ? f.lengthSync() : 0,
          'modifiedAt': f.lastModifiedSync().toIso8601String(),
        });
      }
      entries.sort((a, b) => (b['modifiedAt'] as String).compareTo(a['modifiedAt'] as String));
      return entries;
    } catch (e, s) {
      reportSwallowedError('数据备份列表读取失败', e, s);
      return const [];
    }
  }

  /// P2-12（架构审计 2026-11-12）：校验备份文件是否为有效 SQLite 库。
  ///
  /// 恢复前的安全闸门——只读打开 + quick_check，确证完好才允许替换现库。
  /// 任何异常（文件不存在/不是库/损坏）都返回 false，绝不把坏备份盖到现库上。
  static Future<bool> validateBackup(String backupPath) async {
    final file = File(backupPath);
    if (!file.existsSync() || file.lengthSync() == 0) return false;
    Database? db;
    try {
      db = await openDatabase(backupPath, readOnly: true);
      final check = await db.rawQuery('PRAGMA quick_check');
      final verdict = check.isEmpty ? '' : '${check.first.values.first}';
      return verdict == 'ok';
    } catch (e, s) {
      reportSwallowedError('备份校验失败（$backupPath）', e, s);
      return false;
    } finally {
      try {
        await db?.close();
      } catch (_) {}
    }
  }

  /// P2-12：把校验通过的备份暂存恢复为目标库（调用方须先关闭对应库句柄）。
  ///
  /// 安全口径对齐 user_database._backupAndRebuild：
  /// 1. 先再校验一次备份（防调用方漏校验）；
  /// 2. 现库改名为 `.pre-restore.<时间戳>.bak` 留档（永不覆盖历史），改名失败则
  ///    复制+字节校验，校验通过才移除原文件——唯一副本绝不消失；
  /// 3. 边车（-wal/-shm/-journal）随现库一并移走（残留会让恢复库打开失败）；
  /// 4. 备份复制为目标库；复制失败时现库已在留档处，可人工回退。
  ///
  /// 本方法只做文件替换，不重新打开库——DAO 缓存的句柄需应用重启刷新，
  /// 故恢复成功后由 UI 引导用户重启（见 MoreSettingsPage 恢复入口）。
  static Future<void> restoreBackupFile({required String backupPath, required String targetDbPath}) async {
    if (!await validateBackup(backupPath)) {
      throw StateError('备份未通过完整性校验，拒绝恢复：$backupPath');
    }
    final target = File(targetDbPath);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final preserved = '$targetDbPath.pre-restore.$stamp.bak';

    if (target.existsSync()) {
      try {
        target.renameSync(preserved);
      } catch (e, s) {
        reportSwallowedError('恢复前现库改名留档失败，尝试复制+校验', e, s);
        target.copySync(preserved);
        if (File(preserved).lengthSync() != target.lengthSync()) {
          throw StateError('恢复前现库留档字节数不一致，放弃恢复以防数据丢失');
        }
        target.deleteSync();
      }
    }
    // 边车随现库移走：孤立边车不含可独立恢复的数据，残留会让恢复库打开失败。
    for (final suffix in const ['-journal', '-wal', '-shm']) {
      final sidecar = File('$targetDbPath$suffix');
      if (!sidecar.existsSync()) continue;
      try {
        sidecar.renameSync('$preserved$suffix');
      } catch (e, s) {
        reportSwallowedError('恢复前边车随留档改名失败，删除（$suffix）', e, s);
        try {
          sidecar.deleteSync();
        } catch (_) {}
      }
    }

    await File(backupPath).copy(targetDbPath);
    if (!target.existsSync() || target.lengthSync() == 0) {
      throw StateError('恢复复制未产出有效库文件（现库已留档：$preserved）');
    }
  }

  /// 在线一致性快照。首选 `VACUUM INTO`，低版本 SQLite 降级为「checkpoint + 复制」。
  ///
  /// 为什么必须探测版本（2026-10-15 审计 R3-D01）：
  /// `VACUUM INTO` 需要 SQLite ≥3.27，而 minSdk 24 覆盖的 Android 7/8/9 系统库是
  /// 3.9.2 / 3.18 / 3.19 / 3.22 ⇒ 语句直接语法错。而本服务的失败**只上报不抛出**，
  /// 于是那些设备上备份**永远不会产生**、`listBackups()` 恒空 ——
  /// `user_data.db` / `review_schedule.db` 损坏时**唯一的自动恢复网完全失效**，
  /// 平时毫无征兆。
  ///
  /// 降级路径的保证弱一档（没有「读穿 WAL 的紧凑快照」），但：
  ///   - 先 `wal_checkpoint(TRUNCATE)` 把已提交事务并回主文件（否则裸复制会丢掉最近的事务）；
  ///   - 再 `integrity_check`，坏库不该被当成好备份存下来；
  ///   - 最后才复制主文件（此时连接已关闭，无并发写）。
  /// 「保证弱一点的备份」远好于「什么都没有」。
  static Future<void> _snapshot(String sourcePath, String targetPath) async {
    final tmp = '$targetPath.partial';
    final tmpFile = File(tmp);
    if (tmpFile.existsSync()) tmpFile.deleteSync();

    Database? db;
    var produced = false;
    try {
      // 降级路径要写 WAL 检查点，故不能开只读连接。
      db = await openDatabase(sourcePath);
      if (await _supportsVacuumInto(db)) {
        // 已探过 sqlite_version() ≥3.27 才走到这里（见 _supportsVacuumInto）。
        await db.rawQuery('VACUUM INTO ?', [tmp]); // sqlite-compat-ok: 上方已做版本探测
        produced = true;
      } else {
        // 审计 A8（2026-11-16）：TRUNCATE 返回 busy=1 表示有并发读连接未退，
        // WAL 未并回主文件——旧实现不检查即裸复制，备份静默滞后最近事务。
        // 重试三次；仍 busy 则抛错放弃本次备份（宁可无新备份，不可存滞后快照）。
        var busy = true;
        for (var attempt = 0; attempt < 3 && busy; attempt++) {
          if (attempt > 0) await Future<void>.delayed(const Duration(milliseconds: 100));
          final rows = await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
          busy = rows.isNotEmpty && (rows.first['busy'] as int? ?? 0) != 0;
        }
        if (busy) {
          throw StateError('备份失败：WAL 检查点持续 busy（并发连接未退），本次放弃以防滞后快照');
        }
        final check = await db.rawQuery('PRAGMA integrity_check');
        final verdict = check.isEmpty ? '' : '${check.first.values.first}';
        if (verdict != 'ok') {
          throw StateError('备份前完整性检查未通过：$verdict');
        }
      }
    } finally {
      try {
        await db?.close();
      } catch (_) {}
    }

    if (!produced) {
      await File(sourcePath).copy(tmp);
    }
    if (!tmpFile.existsSync() || tmpFile.lengthSync() == 0) {
      throw StateError('备份未产出有效快照');
    }

    final target = File(targetPath);
    if (target.existsSync()) target.deleteSync();
    tmpFile.renameSync(targetPath);
  }

  /// `VACUUM INTO` 是否可用（SQLite ≥3.27）。进程内只探一次。
  static bool? _vacuumIntoSupported;

  @visibleForTesting
  static set vacuumIntoSupportedOverrideForTest(bool? value) => _vacuumIntoSupported = value;

  static Future<bool> _supportsVacuumInto(Database db) async {
    final cached = _vacuumIntoSupported;
    if (cached != null) return cached;
    var ok = false;
    try {
      final rows = await db.rawQuery('SELECT sqlite_version() AS v');
      ok = _versionAtLeast('${rows.isEmpty ? '' : rows.first['v']}', 3, 27);
    } catch (e, s) {
      // 读不到版本就按「不支持」处理：降级路径总是能跑，猜错方向也不会丢备份。
      reportSwallowedError('读取 SQLite 版本失败（按不支持在线快照处理）', e, s);
    }
    _vacuumIntoSupported = ok;
    return ok;
  }

  static bool _versionAtLeast(String version, int wantMajor, int wantMinor) {
    final parts = version.split('.');
    if (parts.isEmpty) return false;
    final major = int.tryParse(parts[0]) ?? 0;
    final minor = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    if (major != wantMajor) return major > wantMajor;
    return minor >= wantMinor;
  }

  /// M3：SP 全量快照落盘（类型保真 JSON，凭证键已在注册表排除）。
  /// 先写 .partial 再原子改名——半截 JSON 绝不会被恢复侧当成有效备份。
  static Future<void> _snapshotSp(String targetPath) async {
    final snapshot = await UserDataSpRegistry.capture();
    final payload = {
      'schemaVersion': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'entries': {for (final e in snapshot.entries) e.key: e.value.toJson()},
    };
    final tmp = File('$targetPath.partial');
    await tmp.writeAsString(jsonEncode(payload), flush: true);
    final target = File(targetPath);
    if (target.existsSync()) target.deleteSync();
    tmp.renameSync(targetPath);
  }

  /// M3：读取并校验 SP 快照（恢复侧消费）。损坏/缺失返回 null。
  static Future<Map<String, SpSnapshotEntry>?> readSpSnapshot(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync() || file.lengthSync() == 0) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final entries = decoded['entries'];
      if (entries is! Map<String, dynamic>) return null;
      final result = <String, SpSnapshotEntry>{};
      for (final e in entries.entries) {
        final raw = e.value;
        if (raw is! Map<String, dynamic>) continue;
        final entry = SpSnapshotEntry.fromJson(raw);
        if (entry != null) result[e.key] = entry;
      }
      return result;
    } catch (e, s) {
      reportSwallowedError('SP 快照读取失败（$path）', e, s);
      return null;
    }
  }

  /// 每类备份只保留最近 [keepCount] 份（按文件名中的日期戳排序）。
  static Future<void> _pruneOldBackups(Directory backupDir, String dbName, String suffix) async {
    final prefix = '$dbName-';
    final files = backupDir.listSync().whereType<File>().where((f) {
      final name = p.basename(f.path);
      return name.startsWith(prefix) && name.endsWith(suffix);
    }).toList()..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    for (var i = keepCount; i < files.length; i++) {
      try {
        await files[i].delete();
      } catch (e, s) {
        reportSwallowedError('备份清理失败（${p.basename(files[i].path)}）', e, s);
      }
    }
  }

  static Future<void> _writeManifest(Directory backupDir, DateTime at, Map<String, int> files) async {
    final manifest = {
      'schemaVersion': 1,
      'savedAt': at.toIso8601String(),
      'files': [
        for (final e in files.entries) {'name': p.basename(e.key), 'bytes': e.value},
      ],
    };
    await File(p.join(backupDir.path, _manifestName)).writeAsString(jsonEncode(manifest), flush: true);
  }

  static String _dateStamp(DateTime t) =>
      '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}';
}
