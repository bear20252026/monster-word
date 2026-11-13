// P2-12（架构审计 2026-11-12）：备份恢复服务测试。
// validateBackup 只读打开 + quick_check 闸门；restoreBackupFile 现库留档 +
// 边车随行 + 复制恢复。用真实临时目录 + FFI 内存/文件库，不依赖平台通道。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/infrastructure/user_data_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    tmp = await Directory.systemTemp.createTemp('mw_backup_restore_test');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  /// 造一个含数据的真实 SQLite 库文件。
  Future<String> makeDb(String name, {String value = 'hello'}) async {
    final path = p.join(tmp.path, name);
    final db = await openDatabase(path);
    await db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');
    await db.insert('t', {'id': 1, 'v': value});
    await db.close();
    return path;
  }

  group('validateBackup', () {
    test('有效库返回 true', () async {
      final path = await makeDb('good.db');
      expect(await UserDataBackupService.validateBackup(path), isTrue);
    });

    test('不存在的文件返回 false', () async {
      expect(await UserDataBackupService.validateBackup(p.join(tmp.path, 'nope.db')), isFalse);
    });

    test('空文件返回 false', () async {
      final path = p.join(tmp.path, 'empty.db');
      await File(path).writeAsBytes([]);
      expect(await UserDataBackupService.validateBackup(path), isFalse);
    });

    test('非 SQLite 内容返回 false', () async {
      final path = p.join(tmp.path, 'garbage.db');
      await File(path).writeAsString('this is not a database');
      expect(await UserDataBackupService.validateBackup(path), isFalse);
    });
  });

  group('restoreBackupFile', () {
    test('恢复成功：目标库内容来自备份，现库留档保留', () async {
      final backup = await makeDb('backup.db', value: 'from_backup');
      final target = await makeDb('target.db', value: 'old_current');

      await UserDataBackupService.restoreBackupFile(backupPath: backup, targetDbPath: target);

      // 目标库现在是备份的内容
      final db = await openDatabase(target, readOnly: true);
      final rows = await db.query('t');
      expect(rows.single['v'], 'from_backup');
      await db.close();

      // 现库留档存在且含旧内容
      final preserved = tmp
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).contains('.pre-restore.'))
          .toList();
      expect(preserved, hasLength(1));
      final oldDb = await openDatabase(preserved.single.path, readOnly: true);
      expect((await oldDb.query('t')).single['v'], 'old_current');
      await oldDb.close();
    });

    test('坏备份拒绝恢复，现库原样保留', () async {
      final badBackup = p.join(tmp.path, 'bad.db');
      await File(badBackup).writeAsString('not a database');
      final target = await makeDb('target.db', value: 'keep_me');

      await expectLater(
        UserDataBackupService.restoreBackupFile(backupPath: badBackup, targetDbPath: target),
        throwsA(isA<StateError>()),
      );

      final db = await openDatabase(target, readOnly: true);
      expect((await db.query('t')).single['v'], 'keep_me');
      await db.close();
    });

    test('目标库不存在时直接恢复（无留档）', () async {
      final backup = await makeDb('backup.db', value: 'fresh');
      final target = p.join(tmp.path, 'new_target.db');

      await UserDataBackupService.restoreBackupFile(backupPath: backup, targetDbPath: target);

      final db = await openDatabase(target, readOnly: true);
      expect((await db.query('t')).single['v'], 'fresh');
      await db.close();
    });

    test('边车随现库留档移走，不残留', () async {
      final backup = await makeDb('backup.db', value: 'from_backup');
      final target = await makeDb('target.db', value: 'old');
      // 造一个孤立边车
      await File('$target-wal').writeAsString('stale wal');

      await UserDataBackupService.restoreBackupFile(backupPath: backup, targetDbPath: target);

      expect(File('$target-wal').existsSync(), isFalse, reason: '边车已随留档移走');
      final db = await openDatabase(target, readOnly: true);
      expect((await db.query('t')).single['v'], 'from_backup');
      await db.close();
    });
  });
}
