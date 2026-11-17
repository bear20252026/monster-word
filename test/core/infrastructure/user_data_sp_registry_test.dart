// 第四轮审计 M3（2026-11-17）：SP 备份注册表测试。
// 全量快照 + 凭证排除 + 类型保真 + 先清后写恢复语义。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/infrastructure/user_data_sp_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('capture 全量快照与凭证排除', () {
    test('五类原生类型保真采集，凭证键绝不入快照', () async {
      SharedPreferences.setMockInitialValues({
        'scare_coin.balance': 42,
        'scare_coin.protection.count': 3,
        'llm_enabled_v1': true,
        'font_scale': 1.25,
        'monster_name': '咕噜',
        'favorite_words_v1': ['alpha', 'beta'],
        // 凭证键：必须被排除
        'user_token': 'SECRET_TOKEN',
        'user_secret': 'SECRET_SECRET',
        'monster_word_user_info': '{"token":"SECRET"}',
      });

      final snapshot = await UserDataSpRegistry.capture();

      expect(snapshot.keys, isNot(contains('user_token')));
      expect(snapshot.keys, isNot(contains('user_secret')));
      expect(snapshot.keys, isNot(contains('monster_word_user_info')));
      expect(snapshot['scare_coin.balance']!.type, 'int');
      expect(snapshot['scare_coin.balance']!.value, 42);
      expect(snapshot['llm_enabled_v1']!.type, 'bool');
      expect(snapshot['font_scale']!.type, 'double');
      expect(snapshot['font_scale']!.value, 1.25);
      expect(snapshot['monster_name']!.type, 'String');
      expect(snapshot['favorite_words_v1']!.type, 'List<String>');
      expect(snapshot['favorite_words_v1']!.value, ['alpha', 'beta']);
    });

    test('JSON 往返保真（备份落盘→读回）', () {
      const entry = SpSnapshotEntry(type: 'List<String>', value: ['a', 'b']);
      final round = SpSnapshotEntry.fromJson(entry.toJson());
      expect(round, isNotNull);
      expect(round!.type, 'List<String>');
      expect(round.value, ['a', 'b']);
      // 类型不符的损坏条目整条丢弃
      expect(SpSnapshotEntry.fromJson({'type': 'int', 'value': 'not-int'}), isNull);
      expect(SpSnapshotEntry.fromJson({'type': 'unknown', 'value': 1}), isNull);
    });
  });

  group('restore 先清后写 + 凭证保留', () {
    test('恢复回到备份时刻：备份后新增键消失，凭证键现值保留', () async {
      SharedPreferences.setMockInitialValues({
        'scare_coin.balance': 100,
        'monster_name': '旧名',
        'user_token': 'CURRENT_TOKEN',
        'backup_after_new_key': 'should_vanish',
      });

      // 备份时刻的快照（不含 backup_after_new_key）
      final snapshot = {
        'scare_coin.balance': const SpSnapshotEntry(type: 'int', value: 100),
        'monster_name': const SpSnapshotEntry(type: 'String', value: '旧名'),
      };
      // 模拟备份后 SP 又变了
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('scare_coin.balance', 999);
      await prefs.setString('monster_name', '新名');

      final ok = await UserDataSpRegistry.restore(snapshot);
      expect(ok, isTrue);

      final after = await SharedPreferences.getInstance();
      expect(after.getInt('scare_coin.balance'), 100, reason: '余额回到备份时刻');
      expect(after.getString('monster_name'), '旧名');
      expect(after.containsKey('backup_after_new_key'), isFalse, reason: '备份后新增键必须消失（防 SP 与 DB 不同步）');
      expect(after.getString('user_token'), 'CURRENT_TOKEN', reason: '凭证不属备份面，现值保留');
    });

    test('旧备份混入凭证键也拒写（双保险）', () async {
      SharedPreferences.setMockInitialValues({'user_token': 'CURRENT'});
      final snapshot = {
        'user_token': const SpSnapshotEntry(type: 'String', value: 'FROM_BACKUP'),
        'monster_name': const SpSnapshotEntry(type: 'String', value: '咕噜'),
      };
      final ok = await UserDataSpRegistry.restore(snapshot);
      expect(ok, isTrue);
      final after = await SharedPreferences.getInstance();
      expect(after.getString('user_token'), 'CURRENT');
      expect(after.getString('monster_name'), '咕噜');
    });
  });
}
