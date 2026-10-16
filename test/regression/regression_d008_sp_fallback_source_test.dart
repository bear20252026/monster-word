// R3-D08 回归：SQLite 事务失败后的「SP 回退」必须真的换源/保住幂等键。
//
// **缺陷原形**（2026-10-15 审计）：`_checkInLocked` 的 catch 只
// `reportSwallowedError` 后「落入下方 SP 路径」，但那个分支调用的 `_apply`
// 内部会**重新取一次账本**（`_sqliteLedger()`）。失败发生在**事务执行期**、
// 开库本身是好的 ⇒ 账本仍可用 ⇒ 所谓「回退」又走 `ledger.applyDelta` 把 +10
// 写回了账本，而那条路径**不写 `reward_events` 的 `checkin:<date>` 事件键**。
//
// 于是幂等双闸同时失守：
//   ① 事件键没占 ⇒ SQLite 侧认为「今天没签过」；
//   ② 若同期 SP 标记（`last_checkin`）也写失败 ⇒ SP 侧也认为「今天没签过」。
// 两边都记不住 ⇒ 同一自然日可重复领取签到奖励。
//
// **修复**（2026-10-16）：catch 里置 `sqliteRetryWithEvent = true`，随后用
// **带事件键**的写入重试一次 —— 现实中的失败（表缺失、锁竞争、触发器报错）
// 在这一步就恢复，幂等键被正确占用。
//
// **刻意不走的岔路**：直接强制写纯 SP 快照。`balance()` 读时同样偏好账本
// （`if (ledger != null) return ledger.balance()`），写 SP 而读账本会让用户看到
// 「+10 成功」但余额纹丝不动 —— 比原缺陷更糟。所以仅当账本**真的取不到**时才
// 降级纯 SP（此时写读同源，口径一致）。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/infrastructure/scare_coin_ledger_dao.dart';
import 'package:word_app/features/scare_coin/data/preferences_scare_coin_store.dart';

void main() {
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

  group('R3-D08 签到事务失败后的降级必须保住幂等键 / 写读同源', () {
    test('事件表缺失（首轮与重试都失败）：不得出现「占不到事件键却把币写进账本」', () async {
      // ⚠️ 刻意**不建** reward_events ⇒ applyDeltaWithEvent 必抛错，
      //    模拟「事务执行期失败但开库正常」——这正是缺陷被触发的前提。
      SharedPreferences.setMockInitialValues({});
      final store = PreferencesScareCoinStore(ledgerDao: ScareCoinLedgerDao(openDatabase: () async => db));

      final balance = await store.checkIn();

      // 核心判据：**不存在**「账本里有流水、但事件键没被占」这种半吊子状态。
      // 修复前正是这个组合：applyDelta 写成功、reward_events 一行都没有。
      final entries = await db.query('scare_coin_entries');
      final events = await db.query('reward_events');
      expect(entries.isEmpty || events.isNotEmpty, isTrue, reason: '存在无事件键保护的账本流水 = R3-D08 根因（同日可重复发放）');
      expect(balance, isNotNull, reason: '降级不等于不工作：币仍应发出');
    });

    test('账本取不到时降级纯 SP：写读同源，余额可见且不翻倍', () async {
      // 用一个必然开库失败的 dao ⇒ _sqliteLedger() 恒返回 null
      SharedPreferences.setMockInitialValues({});
      final store = PreferencesScareCoinStore(
        ledgerDao: ScareCoinLedgerDao(openDatabase: () async => throw StateError('db unavailable')),
      );

      final first = await store.checkIn();
      expect(first, store.checkInReward, reason: '纯 SP 路径应正常发放');
      expect(await store.balance(), store.checkInReward, reason: '写 SP 读 SP：余额必须可见（若写 SP 读账本则余额纹丝不动，比原缺陷更糟）');

      // 模拟 SP 标记也丢（两道闸的一半失守）
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(PreferencesScareCoinStore.lastCheckInKey);

      final second = await store.checkIn();
      expect(second, isNull, reason: 'SP 快照里的当日流水是第二道闸，必须拦住');
      expect(await store.balance(), store.checkInReward, reason: '不得翻倍');
    });

    test('对照：账本与事件表齐备时，正常路径占事件键（修复未改坏正常流程）', () async {
      await db.execute('CREATE TABLE IF NOT EXISTS reward_events (event_key TEXT PRIMARY KEY, created_at INTEGER)');
      SharedPreferences.setMockInitialValues({});
      final store = PreferencesScareCoinStore(ledgerDao: ScareCoinLedgerDao(openDatabase: () async => db));

      expect(await store.checkIn(), store.checkInReward);

      expect(await db.query('scare_coin_entries'), hasLength(1), reason: '正常路径走账本');
      expect(
        await db.query('reward_events', where: 'event_key = ?', whereArgs: ['checkin:${_todayIso()}']),
        hasLength(1),
        reason: '事件键必须被占用 —— 这是并发幂等的唯一硬依据',
      );
      expect(await store.balance(), store.checkInReward);

      expect(await store.checkIn(), isNull, reason: '同日二次签到被拒');
      expect(await db.query('scare_coin_entries'), hasLength(1), reason: '流水仍只有一条');
    });
  });
}

String _todayIso() => DateTime.now().toIso8601String().substring(0, 10);
