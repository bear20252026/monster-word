import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/infrastructure/scare_coin_ledger_dao.dart';
import 'package:word_app/core/utils/calendar_days.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/models/scare_coin_entry.dart';

/// 尖叫币账本适配器。
///
/// P0-4（I18）：余额与流水下沉 SQLite（ScareCoinLedgerDao，答对记账从
/// 全量 200 条 JSON 读改写降为单事务两行写）；签到日期/保护卡/答对日计数
/// 仍是低频小标量，留在 SharedPreferences。FLUTTER_TEST 未注入数据库、
/// 或开库失败时账本自动回退本类原有的 SP 路径（行为与迁移前一致）。
class PreferencesScareCoinStore implements ScareCoinStore {
  PreferencesScareCoinStore({ScareCoinLedgerDao? ledgerDao}) : _ledgerDao = ledgerDao ?? ScareCoinLedgerDao.instance;

  final ScareCoinLedgerDao _ledgerDao;

  /// 变更操作串行闸（审计：TOCTOU）。checkIn/grantAnswerReward/addProtection/
  /// grant 都是「异步读 → 判 → 写」结构，无闸时并发双击可同读旧值同过检查，
  /// 产生重复入账/突破日上限/丢失更新。单写者队列化后读与写之间不会交错。
  Future<void> _writeQueue = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final run = _writeQueue.then((_) => action());
    // 单次失败不断流（下一个操作照常排队），异常原样还给调用方。
    _writeQueue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// 关键持久化写：SP 在磁盘满/背板异常时返回 false 而非抛错，
  /// 静默忽略会让计数/库存与余额失真（名额被烧、卡未到账）。
  Future<void> _writeChecked(Future<bool> write, String label) async {
    if (!await write) {
      throw StateError('SharedPreferences 写入失败：$label');
    }
  }

  static const String balanceKey = 'scare_coin.balance';
  static const String historyKey = 'scare_coin.history';
  static const String lastCheckInKey = 'scare_coin.last_checkin';
  static const String checkinDatesKey = 'scare_coin.checkin_dates';

  /// 断签保护卡库存／已发里程碑（耗材，独立 key：勿复用 scare_coin.redeemed.*
  /// 前缀，否则 redeemedBadgeCount 虚增、装备 owned/3 错乱）。
  static const String protectionKey = 'scare_coin.protection.count';
  static const String protectionIssuedKey = 'scare_coin.protection.issued';

  /// 答对即时奖励日计数（＋1／次，每日 answerRewardCapValue 封顶）。
  static const String answerRewardDateKey = 'scare_coin.answer_reward.date';
  static const String answerRewardCountKey = 'scare_coin.answer_reward.count';
  static const int reward = 10;

  /// 进程内「整体降级到 SP」粘性标志（R3-D08 收口）。
  ///
  /// 为什么必须是**粘性 + 实例级**，而不是 `_apply` 的局部参数：
  /// 只让写侧换源是不够的 —— `balance()` / `history()` / `checkinDates()`
  /// 都是**读侧**，它们同样偏好账本。若只把这一次的币写进 SP、读侧仍走账本，
  /// 用户会看到「签到成功」但余额纹丝不动 —— 比原缺陷更糟。
  ///
  /// 因此把「账本写事务失败 ⇒ 账本这个源此刻不可信」记在实例上，
  /// 由全类唯一的取库入口 [_sqliteLedger] 统一裁决：置位后**读写一起**
  /// 回退 SP（写读同源）。
  ///
  /// 触发场景真实存在：`reward_events` 是 schema v5 建的、账本表是 v4
  /// （见 user_database.dart `_onUpgrade`），升级到 v5 中途失败（系统杀进程、
  /// 磁盘满）会留下「账本在、事件表不在」——此时开库正常但写事务必炸。
  bool _degradeToSp = false;

  /// 降级后**下一次「写操作」**允许放行一次账本探测（用于自愈）。
  ///
  /// ⚠️ 只在写路径放行，**绝不在读路径放行**：
  /// 降级的语义是「账本这个源此刻不可信」，而判据恰恰是「写事务炸了」。
  /// 读路径若也去探测，会因为**读没炸**（`scare_coin_entries` 存在、
  /// `reward_events` 缺失只影响写）而成功返回**账本里偏低的余额** ⇒
  /// 用户刚看到「签到 +10」紧接着看到余额没变 —— 正是本类反复要避免的
  /// 「写读不同源」。所以读路径在降级期间一律走 SP；账本是否恢复只由
  /// **一次真实写入成功**来证明（[_markLedgerHealthy]）。
  bool _degradeProbePending = false;

  /// SQLite 模式返回就绪的账本 DAO；
  /// 测试环境未注入 / 开库失败 / 已整体降级 → null 走 SP。
  ///
  /// [forWrite] 为 true 表示调用方接下来要**写**账本。只有写路径才消费
  /// [_degradeProbePending] 的自愈探测机会（原因见其注释）。
  Future<ScareCoinLedgerDao?> _sqliteLedger({bool forWrite = false}) async {
    // 已整体降级：默认不再取账本，让所有读写一致地落在 SP 上。
    // 但保留一次**写入**探测机会：账本可能只是暂时不可写（锁竞争），
    // 写成功即自愈回账本模式，避免一次抖动把整个会话钉在 SP 上。
    if (_degradeToSp) {
      if (!forWrite || !_degradeProbePending) return null;
      _degradeProbePending = false; // 机会只用一次，成功与否都由后续写入定论
    }
    final dao = _ledgerDao;
    try {
      await dao.ensureLoaded();
    } catch (e, s) {
      reportSwallowedError('尖叫币账本初始化失败，回退 SP 快照', e, s);
      return null;
    }
    return dao.usesSqlite ? dao : null;
  }

  /// 一次成功的账本写入 ⇒ 账本这个源已恢复可靠，清掉降级标志。
  ///
  /// 只有**写成功**才算数：读成功不足以证明表齐全（`scare_coin_entries`
  /// 读得到、`reward_events` 仍可能缺失）。写路径必然同时触及两张表。
  void _markLedgerHealthy() {
    if (!_degradeToSp) return;
    _degradeToSp = false;
    _degradeProbePending = false;
  }

  /// 进入整体降级：后续读写都走 SP，并给下一次写入留一次自愈探测机会。
  void _enterSpDegradation() {
    _degradeToSp = true;
    _degradeProbePending = true;
  }

  @override
  int get checkInReward => reward;

  @override
  Future<int> balance() async {
    final ledger = await _sqliteLedger();
    if (ledger != null) return ledger.balance();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(balanceKey) ?? 0;
  }

  @override
  Future<Set<String>> checkinDates() async {
    // P1-03：签到日期迁入 user_data.db（与 +10 币同事务域，MW-25 收口）；
    // 首次切换时把 SP 历史快照合并入库（幂等 ignore）。SQLite 不可用回退 SP。
    // forWrite：本方法含一次合并写（addCheckinDates），算写路径。
    final ledger = await _sqliteLedger(forWrite: true);
    if (ledger != null) {
      try {
        final dbDates = await ledger.loadCheckinDates();
        final prefs = await SharedPreferences.getInstance();
        final spDates = (prefs.getStringList(checkinDatesKey) ?? const <String>[]).toSet();
        final merged = <String>{...dbDates, ...spDates};
        if (merged.length > dbDates.length) {
          await ledger.addCheckinDates(merged);
        }
        return merged;
      } catch (e, s) {
        reportSwallowedError('签到日历读取失败，回退 SP 快照', e, s);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(checkinDatesKey) ?? const <String>[]).toSet();
  }

  @override
  Future<int> streak() async {
    final dates = await checkinDates();
    if (dates.isEmpty) return 0;
    var day = DateTime.now();
    bool has(DateTime value) => dates.contains(_iso(value));
    if (!has(day)) day = _dayBefore(day);
    var count = 0;
    while (has(day)) {
      count++;
      day = _dayBefore(day);
    }
    return count;
  }

  /// 日历日前一天（日期分量运算）：Duration(days:1) 是 24h 绝对时长，
  /// 夏令时切换日的 [00:00,01:00) 区间会跳过一整个日历日，误断连击。
  static DateTime _dayBefore(DateTime day) => DateTime(day.year, day.month, day.day - 1);

  @override
  Future<List<ScareCoinEntry>> history() async {
    final ledger = await _sqliteLedger();
    if (ledger != null) return ledger.history();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(historyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final entries = (jsonDecode(raw) as List)
          .map((entry) => ScareCoinEntry.fromJson(entry as Map<String, dynamic>))
          .toList();
      entries.sort((a, b) => b.time.compareTo(a.time));
      return entries;
    } catch (e, s) {
      reportSwallowedError('金币账本解析失败', e, s);
      return [];
    }
  }

  @override
  Future<String> lastCheckInDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(lastCheckInKey) ?? '';
  }

  @override
  bool isSameDay(String isoDate, DateTime time) => isoDate == _iso(time);

  @override
  Future<int?> checkIn() => _serialized(_checkInLocked);

  Future<int?> _checkInLocked() async {
    final now = DateTime.now();
    final last = await lastCheckInDate();
    if (isSameDay(last, now)) return null;
    final iso = _iso(now);
    final prefs = await SharedPreferences.getInstance();

    // R3-D08 的两个降级标志：
    // - sqliteRetryWithEvent：首次事务失败 ⇒ 先「带事件键重试」，保住幂等硬闸；
    // - usedSqliteFallback：带事件键重试也失败（或账本已不可用）⇒ 才降级纯 SP，
    //   此时必须把读路径也固定到 SP（否则写 SP 读账本，余额看起来没变）。
    var sqliteRetryWithEvent = false;
    var usedSqliteFallback = false;

    // ── P1-03：SQLite 模式——「签到事件 + 断签回填 + +10 币 + 流水 + 日历」
    // 同库事务；event_key = checkin:<date> UNIQUE 保证并发 N 个签到只发一次
    // （MW-23），不再依赖 SP 读改写与 UI 防抖。
    final ledger = await _sqliteLedger(forWrite: true);
    if (ledger != null) {
      try {
        if (await ledger.hasRewardEvent('checkin:$iso')) return null;
        // 断签自动续命：有卡则回填最近的缺勤日（先近后远），不断连击。
        await _autoProtectSqlite(ledger, now);
        final newBalance = await ledger.applyDeltaWithEvent(
          delta: checkInReward,
          entry: ScareCoinEntry(time: DateTime.now(), delta: checkInReward, reason: '每日签到'),
          eventKey: 'checkin:$iso',
        );
        await ledger.addCheckinDates({iso});
        // 写成功 ⇒ 账本可用，清掉可能的降级标志（自愈）。
        _markLedgerHealthy();
        // SP 侧标记同步写（last_checkin 是低频标量，供旧路径/展示读取）；
        // 写失败仅上报——SQLite 侧已 durable，重开不会再发（事件键已占用）。
        final saved = await prefs.setString(lastCheckInKey, iso);
        if (!saved) {
          reportSwallowedError('签到日期标记写入失败', StateError('setString returned false'), StackTrace.current);
        }
        // 连签 7 倍数自动发卡（满额跳过发放但仍标记，避免无限囤积）。
        await _maybeIssueProtection(prefs, ledger: ledger);
        return newBalance;
      } on RewardEventDuplicate {
        return null; // 并发重复签到：第二者拿不到事件即无事发生
      } catch (e, s) {
        reportSwallowedError('SQLite 签到事务失败，按 SP 快照口径重试', e, s);
        // R3-D08（2026-10-16）：事务失败后**不能**天真地「落入下方 SP 路径」。
        //
        // 原实现只是不 return，让控制流落到下面的 SP 分支；但那个分支调用的
        // `_apply` 内部会**重新取一次账本**（`_sqliteLedger()`），而失败发生在
        // **事务执行期**（开库是好的）⇒ 账本仍可用 ⇒ 它又走
        // `ledger.applyDelta`，于是「回退」根本没换源，只是**退化成了一条
        // 不占 `checkin:<date>` 事件键的普通流水**。
        // 后果：本次 +10 落进了账本，幂等键却没被占；若同期 SP 标记
        // （`last_checkin`）也写失败，「每日最多一次」的两道闸同时失守
        // ⇒ 同一自然日可重复领取。
        //
        // 另一条**不能走**的岔路：强制写纯 SP 快照。因为 `balance()` 读取时
        // 同样偏好账本（`if (ledger != null) return ledger.balance()`），
        // 写 SP 而读账本 ⇒ 用户看到「+10 成功」但余额纹丝不动，比原缺陷更糟。
        //
        // 正解（两步降级）：
        //   ① 先用**带事件键**的写入重试一次 —— 现实中的失败（锁竞争、
        //      瞬时 IO 错误）在这步就恢复，幂等键被正确占用（见下方 retry 块）；
        //   ② 重试仍失败才承认降级，但**写与读必须同源**，否则余额看起来没变。
        sqliteRetryWithEvent = true;
      }
    }

    // R3-D08 两步降级之第 ①步：用带事件键的账本写入重试，保住幂等硬闸。
    if (sqliteRetryWithEvent) {
      final retryLedger = await _sqliteLedger(forWrite: true);
      if (retryLedger != null) {
        try {
          if (await retryLedger.hasRewardEvent('checkin:$iso')) return null;
          final retryBalance = await retryLedger.applyDeltaWithEvent(
            delta: checkInReward,
            entry: ScareCoinEntry(time: DateTime.now(), delta: checkInReward, reason: '每日签到'),
            eventKey: 'checkin:$iso',
          );
          await retryLedger.addCheckinDates({iso});
          // 写成功 ⇒ 账本可用，清掉可能的降级标志（自愈）。
          _markLedgerHealthy();
          final saved = await prefs.setString(lastCheckInKey, iso);
          if (!saved) {
            reportSwallowedError('签到日期标记写入失败', StateError('setString returned false'), StackTrace.current);
          }
          await _maybeIssueProtection(prefs, ledger: retryLedger);
          return retryBalance;
        } on RewardEventDuplicate {
          return null;
        } catch (e, s) {
          // 带事件键的重试也失败 ⇒ **整体降级到 SP**（R3-D08 收口）。
          //
          // 为什么不能「只上报、然后让它落到下面的 SP 路径」：
          // 那个分支调用的 `_apply` 会**重新取一次账本**，而这里失败的形态
          // 恰恰是「开库正常、写事务炸」⇒ 账本取得到 ⇒ `_apply` 走
          // `ledger.applyDelta`，**依旧不占事件键**，缺口原样保留。
          //
          // 为什么置的是实例级粘性标志而不是局部变量：
          // `usedSqliteFallback` 只影响这一次的**写**；而 `balance()` 等
          // 读侧同样偏好账本 ⇒ 写 SP 读账本 ⇒ 用户看到「+10 成功」但余额
          // 纹丝不动。置 `_degradeToSp` 后 [_sqliteLedger] 对本实例一律
          // 返回 null，读写**一起**落在 SP 上（写读同源）。
          reportSwallowedError('SQLite 带事件键重试仍失败：本次起整体降级纯 SP（写读同源）', e, s);
          _enterSpDegradation();
          usedSqliteFallback = true;
        }
      } else {
        // 账本此刻不可用 ⇒ SP 路径本来就是正确的源，写读都在 SP，口径一致。
        usedSqliteFallback = true;
      }
    }

    // ── SP 回退路径（原实现，保留幂等双闸）──
    // 幂等双闸：last_checkin 在 _apply 成功之后才写，崩溃落在两写之间时
    // （币已 +10、标记未落），仅凭日期标记会重复入账——账本里已有当日
    // 「每日签到」流水则视为已签到，宁可少发一次也不重复发。
    if (await _checkinAlreadyGranted(iso)) return null;
    // 断签自动续命（SP 快照口径）。
    await _autoProtect(prefs, now);
    try {
      final dates = (prefs.getStringList(checkinDatesKey) ?? const <String>[]).toSet()..add(iso);
      await prefs.setStringList(checkinDatesKey, dates.toList()..sort());
    } catch (e, s) {
      // M9：签到日历集合写失败不阻断主流程，但须上报（连签展示可能缺天）。
      reportSwallowedError('scare_coin checkin dates persist', e, s);
    }
    final newBalance = await _apply(
      delta: checkInReward,
      reason: '每日签到',
      lastCheckInIso: iso,
      // R3-D08：仅当账本真的不可用时才强制 SP；否则 _apply 走账本是**对的**
      // （与 balance() 的读路径同源），此时事件键已由上面的路径占用。
      forceSpSnapshot: usedSqliteFallback,
    );
    // 连签 7 倍数自动发卡（满额跳过发放但仍标记，避免无限囤积）。
    await _maybeIssueProtection(prefs, forceSpSnapshot: usedSqliteFallback);
    return newBalance;
  }

  /// SQLite 侧断签回填：保护卡库存仍在 SP（低频标量），回填日期入本库。
  Future<void> _autoProtectSqlite(ScareCoinLedgerDao ledger, DateTime now) async {
    final last = await lastCheckInDate();
    if (last.isEmpty) return;
    final lastDay = DateTime.tryParse(last);
    if (lastDay == null) return;
    final gap = calendarDaysBetween(lastDay, now);
    if (gap <= 1) return;
    final prefs = await SharedPreferences.getInstance();
    var count = prefs.getInt(protectionKey) ?? 0;
    if (count <= 0) return;
    final backfill = <String>{};
    for (var i = 1; i < gap && backfill.length < count; i++) {
      backfill.add(_iso(DateTime(now.year, now.month, now.day - i)));
    }
    if (backfill.isEmpty) return;
    final dbDates = await ledger.loadCheckinDates();
    final fresh = backfill.difference(dbDates);
    if (fresh.isEmpty) return;
    await ledger.addCheckinDates(fresh);
    count -= fresh.length;
    if (!await prefs.setInt(protectionKey, count)) {
      reportSwallowedError('断签保护回填：库存写失败（保护卡可能多计）', StateError('SP write returned false'), StackTrace.current);
      return;
    }
    try {
      await ledger.appendEntry(ScareCoinEntry(time: DateTime.now(), delta: 0, reason: '断签保护·自动续命×${fresh.length}'));
    } catch (e, s) {
      reportSwallowedError('断签保护流水追加失败（SQLite）', e, s);
    }
  }

  /// 账本（SQLite/SP 同口径）里是否已有当日的签到入账流水。
  Future<bool> _checkinAlreadyGranted(String iso) async {
    try {
      final entries = await history();
      return entries.any((e) => e.delta == checkInReward && e.reason == '每日签到' && _iso(e.time) == iso);
    } catch (e, s) {
      // 读取失败不影响主流程：退回仅按日期标记判定。
      reportSwallowedError('签到幂等流水读取失败', e, s);
      return false;
    }
  }

  @override
  int get protectionCap => protectionCapValue;

  /// 保护卡持有上限（端口常量经实例暴露，presentation 层免直引 data 实现）。
  static const int protectionCapValue = 3;

  /// 答对即时奖励日上限。
  static const int answerRewardCapValue = 20;

  @override
  int get answerRewardDailyCap => answerRewardCapValue;

  @override
  Future<int> grantAnswerReward() => _serialized(_grantAnswerRewardLocked);

  Future<int> _grantAnswerRewardLocked() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    var count = 0;
    if (prefs.getString(answerRewardDateKey) == today) {
      count = prefs.getInt(answerRewardCountKey) ?? 0;
    }
    if (count >= answerRewardCapValue) return 0;

    // ── P1-03：SQLite 模式——「占用名额 + 发币」同事务（MW-24）。
    // event_key = answer:<date>:<count> UNIQUE：并发同读旧计数时只有一个
    // 能插入成功，后继拿递增序号重试，上限由 DB 事件键硬性封顶。
    final ledger = await _sqliteLedger(forWrite: true);
    if (ledger != null) {
      var seq = count;
      while (seq < answerRewardCapValue) {
        try {
          await ledger.applyDeltaWithEvent(
            delta: 1,
            entry: ScareCoinEntry(time: DateTime.now(), delta: 1, reason: '答对＋1'),
            eventKey: 'answer:$today:$seq',
          );
        } on RewardEventDuplicate {
          seq++; // 该序号已被占用（并发），尝试下一序号
          continue;
        } catch (e, s) {
          // 与签到同源（R3-D08）：账本写事务失败时**不能**天真落入下方 SP 路径
          // —— 那个分支的 `_apply` 会重新取到账本、走 `applyDelta`，
          // **依旧不占 answer:<date>:<seq> 事件键** ⇒ 当日名额可被重复使用。
          // 所以置实例级降级标志，让下面的 SP 路径**读写都真的落在 SP**。
          reportSwallowedError('SQLite 答对奖励事务失败，本次起整体降级纯 SP（写读同源）', e, s);
          _enterSpDegradation();
          break; // 落入下方 SP 路径（此时 _sqliteLedger 已返回 null）
        }
        // 写成功 ⇒ 账本可用，清掉可能的降级标志（自愈）。
        _markLedgerHealthy();
        // 名额计数同步 SP（写失败仅上报：SQLite 事件键已封顶当日总额）。
        final okDate = await prefs.setString(answerRewardDateKey, today);
        final okCount = await prefs.setInt(answerRewardCountKey, seq + 1);
        if (!okDate || !okCount) {
          reportSwallowedError(
            '答对奖励计数同步失败（SQLite 侧已记账）',
            StateError('answer reward SP sync failed'),
            StackTrace.current,
          );
        }
        return 1;
      }
      if (seq >= answerRewardCapValue) return 0;
    }

    // ── SP 回退路径（原实现）──
    // 计数先落盘且校验返回值：写失败直接抛（名额与币都不动），
    // 不能带着旧计数发币——否则同一名额可重复兑换。
    await _writeChecked(prefs.setString(answerRewardDateKey, today), '答对奖励日期');
    await _writeChecked(prefs.setInt(answerRewardCountKey, count + 1), '答对奖励计数');
    try {
      await _apply(delta: 1, reason: '答对＋1');
    } catch (e) {
      // 发币失败回滚日计数：否则该次答题名额被烧掉（计数已 +1、币未发）。
      // 回滚写自身失败只上报（此刻抛出会被外层误读为「发币也失败了」）。
      try {
        await _writeChecked(prefs.setInt(answerRewardCountKey, count), '答对奖励计数回滚');
      } catch (e2, s2) {
        reportSwallowedError('答对奖励计数回滚失败（当日名额可能少计一次）', e2, s2);
      }
      rethrow;
    }
    return 1;
  }

  @override
  Future<int> protectionCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(protectionKey) ?? 0;
  }

  @override
  Future<int> addProtection({required int count, required String reason}) =>
      _serialized(() => _addProtectionLocked(count: count, reason: reason));

  Future<int> _addProtectionLocked({required int count, required String reason}) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(protectionKey) ?? 0;
    // 满额拒收而非静默钳制：调用方（兑换页已扣 200 币）依赖本抛错触发
    // 补偿退款；静默 clamp 会让「扣了币、卡没到手、无退款」三事同时发生。
    if (count > 0 && current >= protectionCapValue) {
      throw StateError('保护卡库存已满（$protectionCapValue 张）');
    }
    final next = (current + count).clamp(0, protectionCapValue);
    // 库存写校验：写失败抛错走调用方退款路径，不能「无卡也无错」。
    await _writeChecked(prefs.setInt(protectionKey, next), '保护卡库存');
    await _insertHistory(prefs, ScareCoinEntry(time: DateTime.now(), delta: 0, reason: reason));
    return next;
  }

  /// 断签自动续命：last 与 today 之间差 gap>1 天且有库存时，
  /// 从近到远回填 min(库存, 缺勤) 天并记账，streak() 自然续上。
  Future<void> _autoProtect(SharedPreferences prefs, DateTime now) async {
    final last = prefs.getString(lastCheckInKey) ?? '';
    if (last.isEmpty) return;
    final lastDay = DateTime.tryParse(last);
    if (lastDay == null) return;
    // 日历日差（DST 安全，与 _dayBefore 同族口径）：
    // 绝对时长差在夏令时周少算 1 天→该回填的断签日不回填。
    final gap = calendarDaysBetween(lastDay, now);
    if (gap <= 1) return;
    var count = prefs.getInt(protectionKey) ?? 0;
    if (count <= 0) return;
    final backfill = <String>[];
    for (var i = 1; i < gap && backfill.length < count; i++) {
      backfill.add(_iso(DateTime(now.year, now.month, now.day - i)));
    }
    if (backfill.isEmpty) return;
    final dates = (prefs.getStringList(checkinDatesKey) ?? const <String>[]).toSet()..addAll(backfill);
    await prefs.setStringList(checkinDatesKey, dates.toList()..sort());
    count -= backfill.length;
    if (!await prefs.setInt(protectionKey, count)) {
      // 回填已入日历但库存未扣：上报对账（比静默多一张卡诚实）。
      reportSwallowedError('断签保护回填：库存写失败（保护卡可能多计）', StateError('SP write returned false'), StackTrace.current);
      return;
    }
    await _insertHistory(prefs, ScareCoinEntry(time: now, delta: 0, reason: '断签保护·自动续命×${backfill.length}'));
  }

  /// 连签 7 倍数发卡（去重标记防重复领，满额只标记不发放）。
  /// [ledger] 非 null 时流水走 SQLite（签到事务同域）；null 走 SP 快照。
  /// [forceSpSnapshot] 为 true 时无视 [ledger] 强制走 SP 流水（R3-D08：
  /// SQLite 事务失败后的降级必须一路贯彻，不能只降币不降流水）。
  Future<void> _maybeIssueProtection(
    SharedPreferences prefs, {
    ScareCoinLedgerDao? ledger,
    bool forceSpSnapshot = false,
  }) async {
    final effectiveLedger = forceSpSnapshot ? null : ledger;
    final newStreak = await streak();
    if (newStreak <= 0 || newStreak % 7 != 0) return;
    final issued = (prefs.getStringList(protectionIssuedKey) ?? const <String>[]).toSet();
    if (!issued.add('$newStreak')) return;
    if (!await prefs.setStringList(protectionIssuedKey, issued.toList()..sort())) {
      // 去重标记未落盘：上报（次日若 streak 仍为同档 7 倍数有重复发卡窗口）。
      reportSwallowedError('连签发卡：去重标记写失败', StateError('SP write returned false'), StackTrace.current);
      return;
    }
    final count = prefs.getInt(protectionKey) ?? 0;
    if (count >= protectionCapValue) {
      // 满额只标记不发放，但留一条流水：否则审计面上「视为已发」却查无此事。
      await _recordZeroDelta(effectiveLedger, prefs, '连签$newStreak天·发卡满额未发放');
      return;
    }
    if (!await prefs.setInt(protectionKey, count + 1)) {
      reportSwallowedError('连签发卡：库存写失败（卡未到账）', StateError('SP write returned false'), StackTrace.current);
      return;
    }
    await _recordZeroDelta(effectiveLedger, prefs, '连签$newStreak天·保护卡＋1');
  }

  /// 零变动流水：ledger 在则 SQLite（失败不阻断），否则 SP 快照。
  Future<void> _recordZeroDelta(ScareCoinLedgerDao? ledger, SharedPreferences prefs, String reason) async {
    final entry = ScareCoinEntry(time: DateTime.now(), delta: 0, reason: reason);
    if (ledger != null) {
      try {
        await ledger.appendEntry(entry);
      } catch (e, s) {
        reportSwallowedError('零变动流水追加失败（SQLite）', e, s);
      }
      return;
    }
    await _insertHistory(prefs, entry);
  }

  /// 零币变动也记账（发卡／续命审计）。SQLite 模式为追加单行写；
  /// SP 回退路径复用 200 条截断口径，解析失败保留原账本。
  Future<void> _insertHistory(SharedPreferences prefs, ScareCoinEntry entry) async {
    final ledger = await _sqliteLedger(forWrite: true);
    if (ledger != null) {
      try {
        await ledger.appendEntry(entry);
      } catch (e, s) {
        // 与 SP 路径同口径：宁丢一条新账，不抛断发卡/续命主流程。
        reportSwallowedError('尖叫币流水追加失败（SQLite）', e, s);
      }
      return;
    }
    List<ScareCoinEntry> entries = [];
    final raw = prefs.getString(historyKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        entries = (jsonDecode(raw) as List).map((e) => ScareCoinEntry.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e, s) {
        // 数据完整性审计 P2：A 级文件（金币账本）吞错后继续以仅含
        // 新记录的列表覆写，会把原有最多 200 条账本静默清空。
        // 改为上报并保留 raw 原样，宁可丢一条新账也不清账本。
        reportSwallowedError('金币账本追加写入时解析失败，保留原账本', e, s);
        return;
      }
    }
    entries.insert(0, entry);
    await prefs.setString(historyKey, jsonEncode(entries.take(200).map((e) => e.toJson()).toList()));
  }

  @override
  Future<int> grant({required int delta, required String reason}) =>
      _serialized(() => _apply(delta: delta, reason: reason));

  /// [forceSpSnapshot] 为 true 时**强制走纯 SP 分支**（账本可用也不碰）。
  ///
  /// 只有一种调用场景需要它（R3-D08）：签到路径的账本**真的取不到**
  /// （`_sqliteLedger()` 返回 null）。此时 `balance()` 同样读不到账本，
  /// 写 SP + 读 SP 口径一致。
  ///
  /// ⚠️ **不要**在「账本可用、只是写事务失败」时用它：`balance()` 读时偏好账本
  /// （`if (ledger != null) return ledger.balance()`），写 SP 而读账本会让用户
  /// 看到「+10 成功」但余额纹丝不动 —— 比漏占幂等键更糟。那种情况应留在账本
  /// 里（写读同源），靠上层带事件键重试来补幂等。
  Future<int> _apply({
    required int delta,
    required String reason,
    String? lastCheckInIso,
    bool forceSpSnapshot = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final ledger = forceSpSnapshot ? null : await _sqliteLedger(forWrite: true);
    if (ledger != null) {
      // 余额变动与流水追加同事务：负余额拒绝时两者都不落库，
      // 语义与 SP 路径的 TOCTOU 守卫一致。
      final newBalance = await ledger.applyDelta(
        delta: delta,
        entry: ScareCoinEntry(time: DateTime.now(), delta: delta, reason: reason),
      );
      // 写成功 ⇒ 账本可用，清掉可能的降级标志（自愈）。
      _markLedgerHealthy();
      if (lastCheckInIso != null) {
        // 标记写失败上报（余额/库存均走 _writeChecked，此处曾漏网；仅靠流水幂等兑底）。
        final saved = await prefs.setString(lastCheckInKey, lastCheckInIso);
        if (!saved) {
          reportSwallowedError(
            '签到日期标记写入失败',
            StateError('setString($lastCheckInIso) returned false'),
            StackTrace.current,
          );
        }
      }
      return newBalance;
    }
    final current = prefs.getInt(balanceKey) ?? 0;
    final newBalance = current + delta;
    // 数据完整性审计 P2：负向变动不允许把余额写穿为负（兑换页的余额检查
    // 存在 TOCTOU 窗口，双击/并发下曾可产生负余额账本）。
    if (newBalance < 0) {
      throw StateError('余额不足：current=$current, delta=$delta');
    }
    // 余额写校验：写失败抛错（币不能「看起来发出去了」实际没落盘），
    // 抛出时流水尚未追加，账面保持一致。
    await _writeChecked(prefs.setInt(balanceKey, newBalance), '尖叫币余额（SP 回退路径）');
    if (lastCheckInIso != null) await prefs.setString(lastCheckInKey, lastCheckInIso);
    // 与 _insertHistory 同口径：解析失败保留原账本并上报，本次新条目不落账
    // （宁可丢一条新账也不清账本；余额与签到日已正确写入）。
    List<ScareCoinEntry> entries = [];
    final raw = prefs.getString(historyKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        entries = (jsonDecode(raw) as List).map((e) => ScareCoinEntry.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e, s) {
        reportSwallowedError('金币账本写入时解析失败，保留原账本不覆写', e, s);
        return newBalance;
      }
    }
    entries.insert(0, ScareCoinEntry(time: DateTime.now(), delta: delta, reason: reason));
    await prefs.setString(historyKey, jsonEncode(entries.take(200).map((entry) => entry.toJson()).toList()));
    return newBalance;
  }

  String _iso(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
