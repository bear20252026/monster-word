import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/features/scare_coin/data/preferences_scare_coin_store.dart';
import 'package:word_app/core/infrastructure/scare_coin_ledger_dao.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('签到只成功一次并写入余额、日期和流水', () async {
    final store = PreferencesScareCoinStore();

    final firstBalance = await store.checkIn();
    final secondBalance = await store.checkIn();

    expect(firstBalance, store.checkInReward);
    expect(secondBalance, isNull);
    expect(await store.balance(), store.checkInReward);
    expect(await store.checkinDates(), hasLength(1));
    expect(await store.history(), hasLength(1));
  });

  test('奖励流水按时间倒序保存且余额可累计', () async {
    final store = PreferencesScareCoinStore();

    await store.grant(delta: 12, reason: '测试奖励');
    await store.grant(delta: -3, reason: '测试扣除');

    final entries = await store.history();
    expect(await store.balance(), 9);
    expect(entries.map((entry) => entry.reason), ['测试扣除', '测试奖励']);
    expect(entries.map((entry) => entry.delta), [-3, 12]);
  });

  group('REG-AUDIT-003 金币账本损坏保护与负余额拒绝', () {
    test('账本损坏：_apply 路径（grant）不覆写原档，余额仍正确', () async {
      const corrupted = '[{"broken":';
      SharedPreferences.setMockInitialValues({'scare_coin.balance': 5, 'scare_coin.history': corrupted});
      final store = PreferencesScareCoinStore();

      final balance = await store.grant(delta: 3, reason: '测试');

      expect(balance, 8, reason: '余额写入与账本写入解耦，金额不受账本损坏影响');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('scare_coin.history'), corrupted, reason: '修复前：解析失败后以仅含 1 条的列表覆写，最多 200 条账本被静默清空');
      expect(await store.balance(), 8);
    });

    test('账本损坏：_insertHistory 路径（addProtection）不覆写原档', () async {
      const corrupted = 'not-a-list';
      SharedPreferences.setMockInitialValues({'scare_coin.protection.count': 0, 'scare_coin.history': corrupted});
      final store = PreferencesScareCoinStore();

      await store.addProtection(count: 1, reason: '测试发卡');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('scare_coin.history'), corrupted, reason: '宁丢一条新账不清原账本');
    });

    test('负余额拒绝：grant 超额抛错且余额不变', () async {
      SharedPreferences.setMockInitialValues({'scare_coin.balance': 2});
      final store = PreferencesScareCoinStore();

      await expectLater(store.grant(delta: -5, reason: '超额兑换'), throwsStateError);
      expect(await store.balance(), 2, reason: '失败变动不得把余额写穿为负（TOCTOU 窗口兜底）');
    });
  });

  group('P0-4 SQLite 模式（注入内存库 Ledger DAO）', () {
    late Database db;

    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await openDatabase(inMemoryDatabasePath);
      await db.execute(
        'CREATE TABLE IF NOT EXISTS scare_coin_entries ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, time_ms INTEGER NOT NULL, delta INTEGER NOT NULL, reason TEXT NOT NULL)',
      );
      await db.execute('CREATE TABLE IF NOT EXISTS scare_coin_meta (key TEXT PRIMARY KEY, value INTEGER NOT NULL)');
    });

    tearDown(() async {
      await db.close();
    });

    PreferencesScareCoinStore sqliteStore({Map<String, Object> spSeed = const {}}) {
      SharedPreferences.setMockInitialValues(spSeed);
      return PreferencesScareCoinStore(ledgerDao: ScareCoinLedgerDao(openDatabase: () async => db));
    }

    test('签到/答对记账走 SQLite：余额与流水入表，签到日期仍写 SP', () async {
      final store = sqliteStore();

      final firstBalance = await store.checkIn();
      expect(firstBalance, store.checkInReward);
      expect(await store.balance(), store.checkInReward);
      expect((await store.history()).single.reason, '每日签到');
      expect(await db.query('scare_coin_entries'), hasLength(1), reason: '流水入 SQLite 表');
      expect(await store.checkinDates(), hasLength(1), reason: '签到日期保持 SP');

      expect(await store.grantAnswerReward(), 1);
      expect(await store.balance(), store.checkInReward + 1);
      expect((await store.history()).first.reason, '答对＋1');
    });

    test('负余额拒绝与损坏迁移口径在 SQLite 模式下不变', () async {
      final store = sqliteStore(spSeed: {'scare_coin.balance': 2, 'scare_coin.history': 'not-a-json'});

      await expectLater(store.grant(delta: -5, reason: '超额兑换'), throwsStateError);
      expect(await store.balance(), 2, reason: 'SP 损坏余额经迁移后同样受负余额守卫');
      expect((await store.history()), isEmpty, reason: '损坏流水不上表、不阻断启用（宁丢存量不清快照）');
    });
  });
}
