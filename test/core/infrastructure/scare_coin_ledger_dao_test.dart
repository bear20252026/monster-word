// P0-4（I18）：ScareCoinLedgerDao 测试。
// SQLite（注入内存库）为事实来源：SP 迁移幂等（标记同事务）、余额/流水
// 同事务、负余额整体回滚；FLUTTER_TEST 下未注入的默认实例回退旧 SP 行为。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/infrastructure/scare_coin_ledger_dao.dart';
import 'package:word_app/models/scare_coin_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    databaseFactory = databaseFactoryFfi;
    db = await openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE IF NOT EXISTS scare_coin_entries ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, time_ms INTEGER NOT NULL, delta INTEGER NOT NULL, reason TEXT NOT NULL)',
    );
    await db.execute('CREATE TABLE IF NOT EXISTS scare_coin_meta (key TEXT PRIMARY KEY, value INTEGER NOT NULL)');
  });

  tearDown(() async {
    if (db.isOpen) {
      await db.close();
    }
  });

  ScareCoinEntry entry(int delta, String reason, {DateTime? at}) =>
      ScareCoinEntry(time: at ?? DateTime(2026, 10, 1, 12), delta: delta, reason: reason);

  group('ScareCoinLedgerDao（SQLite 模式）', () {
    test('SP → SQLite 首启迁移：余额+流水入表、SP 快照保留、重放不重复入账', () async {
      SharedPreferences.setMockInitialValues({
        'scare_coin.balance': 42,
        'scare_coin.history': '[{"t":1760000000000,"d":10,"r":"每日签到"},{"t":1759900000000,"d":32,"r":"答对＋1"}]',
      });

      final dao = ScareCoinLedgerDao(openDatabase: () async => db);
      await dao.ensureLoaded();

      expect(dao.usesSqlite, isTrue);
      expect(await dao.balance(), 42);
      final history = await dao.history();
      expect(history.map((e) => e.reason), ['每日签到', '答对＋1'], reason: 'SP 里 index 0 最新，迁移后时间倒序展示保持旧序');

      final spSnapshot = await SharedPreferences.getInstance();
      expect(spSnapshot.getString('scare_coin.history'), isNotNull, reason: 'SP 快照保留为回滚依据');

      // 二次启动：meta 标记已在库内，不重复迁移（幂等）
      final dao2 = ScareCoinLedgerDao(openDatabase: () async => db);
      await dao2.ensureLoaded();
      expect(await dao2.balance(), 42);
      expect(await dao2.history(), hasLength(2), reason: '重放不得重复入账（流水无唯一键，标记必须同事务）');
    });

    test('账本损坏：余额照迁、流水从零起账，不阻断 SQLite 启用', () async {
      SharedPreferences.setMockInitialValues({'scare_coin.balance': 7, 'scare_coin.history': '[{"broken":'});

      final dao = ScareCoinLedgerDao(openDatabase: () async => db);
      await dao.ensureLoaded();

      expect(dao.usesSqlite, isTrue);
      expect(await dao.balance(), 7, reason: '余额迁移不受流水损坏影响');
      expect(await dao.history(), isEmpty);
    });

    test('applyDelta 单事务两行写；时间倒序、同毫秒按插入序倒序', () async {
      final dao = ScareCoinLedgerDao(openDatabase: () async => db);
      await dao.ensureLoaded();

      final base = DateTime.fromMillisecondsSinceEpoch(1760000000000);
      expect(await dao.applyDelta(delta: 10, entry: entry(10, '答对＋1', at: base)), 10);
      expect(await dao.applyDelta(delta: -3, entry: entry(-3, '兑换', at: base)), 7);
      expect(await dao.balance(), 7);

      final rows = await db.query('scare_coin_entries');
      expect(rows, hasLength(2), reason: '余额变动与流水同事务，一变一插');

      await dao.appendEntry(entry(0, '连签7天·保护卡＋1', at: base));
      final history = await dao.history();
      expect(history.map((e) => e.reason), ['连签7天·保护卡＋1', '兑换', '答对＋1'], reason: '同毫秒按插入序倒序，与旧列表排序口径一致');
    });

    test('负余额拒绝：抛 StateError 且余额与流水整体回滚', () async {
      final dao = ScareCoinLedgerDao(openDatabase: () async => db);
      await dao.ensureLoaded();
      await dao.applyDelta(delta: 2, entry: entry(2, '初始'));

      await expectLater(dao.applyDelta(delta: -5, entry: entry(-5, '超额兑换')), throwsStateError);
      expect(await dao.balance(), 2, reason: '失败变动不得把余额写穿为负（TOCTOU 窗口兜底）');
      expect(await db.query('scare_coin_entries'), hasLength(1), reason: '被拒流水不落表');
    });
  });

  group('ScareCoinLedgerDao（FLUTTER_TEST 未注入 → SP 回退）', () {
    test('保持迁移前的 SP 行为', () async {
      SharedPreferences.setMockInitialValues({'scare_coin.balance': 5});
      final dao = ScareCoinLedgerDao();
      await dao.ensureLoaded();

      expect(dao.usesSqlite, isFalse);
      expect(() => dao.balance(), throwsStateError, reason: 'SP 回退模式由 Store 层兜底，DAO 不读 SP');
    });
    test('P2-2：底层库被外部 close 后自动失效，重新加载即恢复 SQLite 模式', () async {
      var useFreshDb = false;
      final dao = ScareCoinLedgerDao(
        openDatabase: () async {
          if (!useFreshDb) return db;
          final fresh = await openDatabase(inMemoryDatabasePath);
          await fresh.execute(
            'CREATE TABLE IF NOT EXISTS scare_coin_entries ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, time_ms INTEGER NOT NULL, delta INTEGER NOT NULL, reason TEXT NOT NULL)',
          );
          await fresh.execute(
            'CREATE TABLE IF NOT EXISTS scare_coin_meta (key TEXT PRIMARY KEY, value INTEGER NOT NULL)',
          );
          return fresh;
        },
      );
      await dao.ensureLoaded();
      expect(dao.usesSqlite, isTrue);
      expect(await dao.applyDelta(delta: 5, entry: entry(5, '答对＋1')), 5);

      // 模拟 UserDatabase.close()：直接关闭 DAO 持有的句柄（不经 invalidate）
      await db.close();
      useFreshDb = true;

      // 关闭后操作抛 database_closed，且 DAO 自动失效退出「假 SQLite 模式」
      await expectLater(dao.balance(), throwsA(isA<DatabaseException>()));
      expect(dao.usesSqlite, isFalse, reason: 'closed 异常命中后自动失效，不得永久卡在假 SQLite 模式');

      // 失效后重新 ensureLoaded：重走 openDatabase 拿新句柄，SQLite 模式恢复
      await dao.ensureLoaded();
      expect(dao.usesSqlite, isTrue);
      expect(await dao.balance(), 0, reason: '新库无迁移标记，SP 快照为空 → 空账本（重放语义）');
    });
  });
}
