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
      for (final dbName in const ['user_data.db', 'review_schedule.db']) {
        final source = File(p.join(root, dbName));
        if (!source.existsSync() || source.lengthSync() == 0) continue;
        final stamp = _dateStamp(clock);
        final target = p.join(backupDir.path, '$dbName-$stamp.bak');
        try {
          await _vacuumInto(source.path, target);
          backedUp[target] = File(target).lengthSync();
          await _pruneOldBackups(backupDir, dbName);
        } catch (e, s) {
          reportSwallowedError('数据备份失败（$dbName）', e, s);
        }
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
        if (!f.path.endsWith('.bak') && p.basename(f.path) != _manifestName) continue;
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

  /// VACUUM INTO 在线一致性快照：只读连接 + SQLite 读穿 WAL，
  /// 输出的是已完成事务的紧凑完整快照（不是主文件裸复制）。
  static Future<void> _vacuumInto(String sourcePath, String targetPath) async {
    Database? ro;
    try {
      ro = await openDatabase(sourcePath, readOnly: true);
      final tmp = '$targetPath.partial';
      await ro.rawQuery('VACUUM INTO ?', [tmp]);
      final tmpFile = File(tmp);
      if (!tmpFile.existsSync() || tmpFile.lengthSync() == 0) {
        throw StateError('VACUUM INTO 未产出有效快照');
      }
      final target = File(targetPath);
      if (target.existsSync()) target.deleteSync();
      tmpFile.renameSync(targetPath);
    } finally {
      try {
        await ro?.close();
      } catch (_) {}
    }
  }

  /// 每类库只保留最近 [keepCount] 份（按文件名中的日期戳排序）。
  static Future<void> _pruneOldBackups(Directory backupDir, String dbName) async {
    final prefix = '$dbName-';
    final files = backupDir.listSync().whereType<File>().where((f) {
      final name = p.basename(f.path);
      return name.startsWith(prefix) && name.endsWith('.bak');
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
