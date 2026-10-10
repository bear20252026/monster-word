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

  /// SQLite 模式返回就绪的账本 DAO；测试环境未注入 / 开库失败 → null 走 SP。
  Future<ScareCoinLedgerDao?> _sqliteLedger() async {
    final dao = _ledgerDao;
    try {
      await dao.ensureLoaded();
    } catch (e, s) {
      reportSwallowedError('尖叫币账本初始化失败，回退 SP 快照', e, s);
      return null;
    }
    return dao.usesSqlite ? dao : null;
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
    // 幂等双闸：last_checkin 在 _apply 成功之后才写，崩溃落在两写之间时
    // （币已 +10、标记未落），仅凭日期标记会重复入账——账本里已有当日
    // 「每日签到」流水则视为已签到，宁可少发一次也不重复发。
    if (await _checkinAlreadyGranted(_iso(now))) return null;
    final prefs = await SharedPreferences.getInstance();
    // 断签自动续命：有卡则回填最近的缺勤日（先近后远），不断连击。
    await _autoProtect(prefs, now);
    final iso = _iso(now);
    try {
      final dates = (prefs.getStringList(checkinDatesKey) ?? const <String>[]).toSet()..add(iso);
      await prefs.setStringList(checkinDatesKey, dates.toList()..sort());
    } catch (e, s) {
      // M9：签到日历集合写失败不阻断主流程，但须上报（连签展示可能缺天）。
      reportSwallowedError('scare_coin checkin dates persist', e, s);
    }
    final newBalance = await _apply(delta: checkInReward, reason: '每日签到', lastCheckInIso: iso);
    // 连签 7 倍数自动发卡（满额跳过发放但仍标记，避免无限囤积）。
    await _maybeIssueProtection(prefs);
    return newBalance;
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
  Future<void> _maybeIssueProtection(SharedPreferences prefs) async {
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
      await _insertHistory(prefs, ScareCoinEntry(time: DateTime.now(), delta: 0, reason: '连签$newStreak天·发卡满额未发放'));
      return;
    }
    if (!await prefs.setInt(protectionKey, count + 1)) {
      reportSwallowedError('连签发卡：库存写失败（卡未到账）', StateError('SP write returned false'), StackTrace.current);
      return;
    }
    await _insertHistory(prefs, ScareCoinEntry(time: DateTime.now(), delta: 0, reason: '连签$newStreak天·保护卡＋1'));
  }

  /// 零币变动也记账（发卡／续命审计）。SQLite 模式为追加单行写；
  /// SP 回退路径复用 200 条截断口径，解析失败保留原账本。
  Future<void> _insertHistory(SharedPreferences prefs, ScareCoinEntry entry) async {
    final ledger = await _sqliteLedger();
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

  Future<int> _apply({required int delta, required String reason, String? lastCheckInIso}) async {
    final prefs = await SharedPreferences.getInstance();
    final ledger = await _sqliteLedger();
    if (ledger != null) {
      // 余额变动与流水追加同事务：负余额拒绝时两者都不落库，
      // 语义与 SP 路径的 TOCTOU 守卫一致。
      final newBalance = await ledger.applyDelta(
        delta: delta,
        entry: ScareCoinEntry(time: DateTime.now(), delta: delta, reason: reason),
      );
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
