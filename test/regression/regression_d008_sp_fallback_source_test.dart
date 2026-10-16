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
// **修复**（2026-10-16，两轮）：
//   第 ① 轮：catch 里置 `sqliteRetryWithEvent`，先用**带事件键**的写入重试一次。
//   第 ② 轮：重试也失败时，只置 `forceSpSnapshot` 局部变量**仍然不够** ——
//     写侧换了源，读侧 `balance()` 还是偏好账本 ⇒ 用户看到「签到成功」但余额不变。
//     改为置**实例级粘性标志** `_degradeToSp`，由全类唯一的取库入口
//     `_sqliteLedger()` 统一裁决，让**读写一起**落在 SP（写读同源）。
//
// ⚠️ 一个容易写错的细节：自愈探测**只在写路径放行**。
//   降级的判据是「写事务炸了」，而读往往没炸（`scare_coin_entries` 在、
//   `reward_events` 缺只影响写）。若读路径也去探测，就会成功读到**账本里偏低的
//   余额** ⇒ 刚签到完就看到余额没变 —— 正是本类反复要避免的「写读不同源」。
//   所以读在降级期间一律走 SP，账本是否恢复只由**一次真实写入成功**来证明。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/infrastructure/scare_coin_ledger_dao.dart';
import 'package:word_app/features/scare_coin/data/preferences_scare_coin_store.dart';

void main() {
  late Database db;

  // 建表辅助。DAO 一共用到 4 张表（见 scare_coin_ledger_dao.dart）：
  //   scare_coin_entries / scare_coin_meta —— 账本本体
  //   reward_events    —— 幂等事件键（applyDeltaWithEvent 占用）
  //   checkin_dates    —— 签到日历（addCheckinDates / loadCheckinDates）
  // ⚠️ 各用例**按需**建表：D08 的缺陷前提就是「某张表缺失」，
  //    一次性建全会让所有降级分支都变成不可达，测试恒绿而无意义。
  Future<void> createLedgerTables() async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS scare_coin_entries ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, time_ms INTEGER NOT NULL, delta INTEGER NOT NULL, reason TEXT NOT NULL)',
    );
    await db.execute('CREATE TABLE IF NOT EXISTS scare_coin_meta (key TEXT PRIMARY KEY, value INTEGER NOT NULL)');
  }

  Future<void> createEventTable() async {
    await db.execute('CREATE TABLE IF NOT EXISTS reward_events (event_key TEXT PRIMARY KEY, created_at INTEGER)');
  }

  Future<void> createCheckinDatesTable() async {
    await db.execute('CREATE TABLE IF NOT EXISTS checkin_dates (date TEXT PRIMARY KEY)');
  }

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await openDatabase(inMemoryDatabasePath);
  });

  tearDown(() async {
    await db.close();
  });

  group('R3-D08 签到事务失败后的降级必须保住幂等键 / 写读同源', () {
    test('事件表缺失（首轮与重试都失败）：整体降级 SP，写读同源且不留无事件键流水', () async {
      // ⚠️ 刻意**不建** reward_events ⇒ applyDeltaWithEvent 必抛错，
      //    模拟「事务执行期失败但开库正常」——这正是缺陷被触发的前提。
      //    checkin_dates 建上：让失败点集中在事件表，不被无关的表缺失干扰。
      await createLedgerTables();
      await createCheckinDatesTable();
      SharedPreferences.setMockInitialValues({});
      final store = PreferencesScareCoinStore(ledgerDao: ScareCoinLedgerDao(openDatabase: () async => db));

      final balance = await store.checkIn();
      expect(balance, isNotNull, reason: '降级不等于不工作：币仍应发出');
      expect(balance, store.checkInReward, reason: '本次 +10 必须可见');

      // 判据 ①：**不得**把币写进账本。
      // 账本的写事务恰恰是炸了的那条路；若 `applyDelta`（不占事件键）被走到，
      // 就会留下「有流水、无事件键」的半吊子状态 = R3-D08 根因。
      final entries = await db.query('scare_coin_entries', where: 'reason = ?', whereArgs: ['每日签到']);
      expect(entries, isEmpty, reason: 'R3-D08 根因复发：账本里出现签到流水 ⇒ 走的是不占事件键的 applyDelta');

      // 判据 ②：**写读同源** —— 写落在 SP，则 balance() 也必须读到 SP。
      // 修复第 ① 轮的残余缺陷正是「写 SP 读账本」⇒ 用户看到「签到 +10 成功」
      // 但余额纹丝不动，比原缺陷更糟。
      expect(await store.balance(), store.checkInReward, reason: '写 SP 却读账本会让余额看起来没变，比原缺陷更糟');
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
      await createLedgerTables();
      await createEventTable();
      await createCheckinDatesTable();
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

    test('降级期间读路径不得私自探测账本（否则写 SP 读账本 ⇒ 余额看起来没变）', () async {
      // 场景：账本**能读**（entries/meta 都在、余额还是 0）但**写不了**
      //（reward_events 缺失）。这正是降级发生后最容易踩的坑：
      // 降级判据是「写炸了」，而读没炸 —— 若读路径也去探测，就会成功
      // 返回账本里偏低的余额，用户刚看到「签到 +10」紧接着看到余额没变。
      await createLedgerTables();
      await createCheckinDatesTable();
      SharedPreferences.setMockInitialValues({});
      final store = PreferencesScareCoinStore(ledgerDao: ScareCoinLedgerDao(openDatabase: () async => db));

      // 触发降级
      expect(await store.checkIn(), store.checkInReward);

      // 账本此刻仍**读得到**（余额 0，因为币落在 SP 而非账本）——
      // 用它证明「读确实会偏好账本」这个前提成立，测试不是空跑。
      expect(await db.query('scare_coin_meta'), isEmpty, reason: '币没进账本（降级期间写落在 SP）');

      // 关键断言：连续多次读都必须稳定命中 SP，不得因为探测而翻回账本。
      for (var i = 0; i < 3; i++) {
        expect(await store.balance(), store.checkInReward, reason: '第 ${i + 1} 次读：降级期间读路径必须始终走 SP（写读同源）');
      }
      expect(await store.history(), hasLength(1), reason: '流水同样走 SP，与余额口径一致');
    });
  });
}

String _todayIso() => DateTime.now().toIso8601String().substring(0, 10);
