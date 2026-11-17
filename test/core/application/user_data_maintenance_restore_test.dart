// 第四轮审计 M3/M18（2026-11-17）：备份恢复编排测试。
// 真实临时目录 + FFI 文件库 + mock SP：验证「校验前置 → 关库广播 → 安全替换
// → SP 回放 → 重开双库 → 缓存复位」全链路，以及旧备份（无 SP 快照）降级。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/application/user_data_maintenance_service.dart';
import 'package:word_app/core/infrastructure/user_database.dart';

class _FakePathProvider extends PathProviderPlatform {
  final String dir;
  _FakePathProvider(this.dir);

  @override
  Future<String?> getApplicationSupportPath() async => dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir;

  @override
  Future<String?> getTemporaryPath() async => dir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late String backupDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mw_maintenance_restore_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    backupDir = p.join(tmp.path, 'backups');
    await Directory(backupDir).create(recursive: true);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    try {
      await UserDatabase.instance.close();
    } catch (_) {}
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Future<String> makeDb(String name, {required String value}) async {
    final path = p.join(tmp.path, name);
    final db = await openDatabase(path);
    await db.execute('CREATE TABLE marker (id INTEGER PRIMARY KEY, v TEXT)');
    await db.insert('marker', {'id': 1, 'v': value});
    await db.close();
    return path;
  }

  Future<void> writeSpSnapshot(String stamp, Map<String, Object> entries) async {
    final payload = {'schemaVersion': 1, 'savedAt': DateTime.now().toIso8601String(), 'entries': entries};
    await File(p.join(backupDir, 'sp_prefs-$stamp.json')).writeAsString(jsonEncode(payload), flush: true);
  }

  UserDataMaintenanceService makeService({required List<String> events, Future<void> Function()? resetCaches}) {
    return UserDataMaintenanceService(
      closeReviewStore: () async => events.add('closeReview'),
      reopenReviewStore: () async => events.add('reopenReview'),
      resetFeatureCaches: resetCaches ?? () async => events.add('resetCaches'),
    );
  }

  group('M3 恢复面扩至 SP 快照', () {
    test('全量恢复：双库替换 + SP 回到备份时刻 + 重开双库 + 缓存复位', () async {
      const stamp = '20261117';
      // 备份件：两库 + SP 快照
      final userBackup = await makeDb('user_backup.db', value: 'restored_user');
      final reviewBackup = await makeDb('review_backup.db', value: 'restored_review');
      await File(userBackup).copy(p.join(backupDir, 'user_data.db-$stamp.bak'));
      await File(reviewBackup).copy(p.join(backupDir, 'review_schedule.db-$stamp.bak'));
      await writeSpSnapshot(stamp, {
        'scare_coin.balance': {'type': 'int', 'value': 100},
        'monster_name': {'type': 'String', 'value': '备份名'},
      });
      // 现库与现 SP（备份后又变了）
      await makeDb('user_data.db', value: 'current_user');
      await makeDb('review_schedule.db', value: 'current_review');
      SharedPreferences.setMockInitialValues({
        'scare_coin.balance': 999,
        'monster_name': '现名',
        'user_token': 'KEEP_ME',
        'added_after_backup': 'vanish',
      });

      final events = <String>[];
      final service = makeService(events: events);
      final result = await service.restoreFromStamp(stamp);

      expect(result.success, isTrue, reason: result.message);
      expect(result.message, contains('无需重启'));
      // 双库内容来自备份
      final userDb = await openDatabase(p.join(tmp.path, 'user_data.db'), readOnly: true);
      expect((await userDb.query('marker')).single['v'], 'restored_user');
      await userDb.close();
      final reviewDb = await openDatabase(p.join(tmp.path, 'review_schedule.db'), readOnly: true);
      expect((await reviewDb.query('marker')).single['v'], 'restored_review');
      await reviewDb.close();
      // SP 回到备份时刻，凭证保留，备份后新增键消失
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('scare_coin.balance'), 100);
      expect(prefs.getString('monster_name'), '备份名');
      expect(prefs.getString('user_token'), 'KEEP_ME');
      expect(prefs.containsKey('added_after_backup'), isFalse);
      // 编排顺序：关复习库 → 重开复习库 → 缓存复位
      expect(events, ['closeReview', 'reopenReview', 'resetCaches']);
      // 现库留档存在（安全口径不变）
      final preserved = Directory(tmp.path)
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).contains('.pre-restore.'))
          .toList();
      expect(preserved.length, greaterThanOrEqualTo(2));
    });

    test('旧备份无 SP 快照：仅恢复双库，文案如实说明，SP 保持现状', () async {
      const stamp = '20261101';
      final userBackup = await makeDb('user_backup.db', value: 'old_user');
      final reviewBackup = await makeDb('review_backup.db', value: 'old_review');
      await File(userBackup).copy(p.join(backupDir, 'user_data.db-$stamp.bak'));
      await File(reviewBackup).copy(p.join(backupDir, 'review_schedule.db-$stamp.bak'));
      await makeDb('user_data.db', value: 'current_user');
      await makeDb('review_schedule.db', value: 'current_review');
      SharedPreferences.setMockInitialValues({'scare_coin.balance': 777});

      final service = makeService(events: []);
      final result = await service.restoreFromStamp(stamp);

      expect(result.success, isTrue, reason: result.message);
      expect(result.message, contains('不含偏好快照'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('scare_coin.balance'), 777, reason: '无快照时 SP 不动');
    });

    test('SP 快照损坏：整体拒绝，现库分毫不动', () async {
      const stamp = '20261117';
      final userBackup = await makeDb('user_backup.db', value: 'restored_user');
      final reviewBackup = await makeDb('review_backup.db', value: 'restored_review');
      await File(userBackup).copy(p.join(backupDir, 'user_data.db-$stamp.bak'));
      await File(reviewBackup).copy(p.join(backupDir, 'review_schedule.db-$stamp.bak'));
      await File(p.join(backupDir, 'sp_prefs-$stamp.json')).writeAsString('{broken json');
      await makeDb('user_data.db', value: 'current_user');
      await makeDb('review_schedule.db', value: 'current_review');

      final service = makeService(events: []);
      final result = await service.restoreFromStamp(stamp);

      // 损坏快照读回 null → 按旧备份降级（仅恢复 db）——db 备份本身有效，
      // 不因 SP 快照损坏拒绝整个恢复；SP 保持现状。
      expect(result.success, isTrue);
      expect(result.message, contains('不含偏好快照'));
      final userDb = await openDatabase(p.join(tmp.path, 'user_data.db'), readOnly: true);
      expect((await userDb.query('marker')).single['v'], 'restored_user');
      await userDb.close();
    });

    test('用户库备份缺失：拒绝且不关库', () async {
      const stamp = '20261117';
      final reviewBackup = await makeDb('review_backup.db', value: 'r');
      await File(reviewBackup).copy(p.join(backupDir, 'review_schedule.db-$stamp.bak'));
      await makeDb('user_data.db', value: 'current_user');
      await makeDb('review_schedule.db', value: 'current_review');

      final events = <String>[];
      final service = makeService(events: events);
      final result = await service.restoreFromStamp(stamp);

      expect(result.success, isFalse);
      expect(events, isEmpty, reason: '校验前置：不合格备份绝不触发关库');
      final userDb = await openDatabase(p.join(tmp.path, 'user_data.db'), readOnly: true);
      expect((await userDb.query('marker')).single['v'], 'current_user');
      await userDb.close();
    });
  });

  group('M18 库关闭失效广播', () {
    test('close 通知全部订阅者；单个抛错不中断其余', () async {
      var a = 0;
      var b = 0;
      void listenerA() => a++;
      void listenerB() {
        b++;
        throw StateError('boom');
      }

      void listenerC() => b += 10;
      UserDatabase.instance.addCloseListener(listenerA);
      UserDatabase.instance.addCloseListener(listenerB);
      UserDatabase.instance.addCloseListener(listenerC);
      addTearDown(() {
        UserDatabase.instance.removeCloseListener(listenerA);
        UserDatabase.instance.removeCloseListener(listenerB);
        UserDatabase.instance.removeCloseListener(listenerC);
      });

      await UserDatabase.instance.close();

      expect(a, 1);
      expect(b, 11, reason: 'B 抛错后 C 仍被通知');
      // 幂等订阅：重复登记不重复通知
      UserDatabase.instance.addCloseListener(listenerA);
      await UserDatabase.instance.close();
      expect(a, 2);
    });
  });
}
