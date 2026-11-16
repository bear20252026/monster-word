// 学习行为发币服务 — 尖叫币经济与学习行为挂钩。
//
// 设计原则：
// 1. 只奖不罚：答错、中断均不扣币，保持正向激励。
// 2. 防刷：所有奖励按自然日键控（SharedPreferences），跨天自动清零。
//    - 会话完成奖励：每会话一次（由调用方保证），每自然日最多 _sessionDailyCap 次。
//    - 目标达成奖励：每自然日至多一次（日期标记）。
// 3. 诚实入账：走 ScareCoinStore.grant()，账本 reason 为中文，历史页直接可读。
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';

/// 审计 R6（2026-11-16）：条目内部分成功（会话奖已发、目标奖失败）时抛出，
/// 携带本次已实发币数——结算循环据此计入本次结果，再保留条目重试剩余奖励。
class _PartialRewardFailure implements Exception {
  _PartialRewardFailure(this.partialGranted, this.cause);
  final int partialGranted;
  final Object cause;
  @override
  String toString() => 'PartialRewardFailure(granted=$partialGranted, cause=$cause)';
}

/// 会话结算结果：本次实际发出的尖叫币总额（0 表示没有可发奖励）。
class SessionRewardResult {
  const SessionRewardResult({required this.totalGranted, this.goalJustAchieved = false});

  final int totalGranted;
  final bool goalJustAchieved;
}

class LearningRewardService {
  LearningRewardService(this._store);

  final ScareCoinStore _store;

  static const int _sessionMinWords = 10;
  static const int _sessionReward = 5;
  static const int _sessionDailyCap = 3;
  static const int _goalReward = 20;

  static const String _kSessionDate = 'scare_coin.reward.session_date';
  static const String _kSessionCount = 'scare_coin.reward.session_count';
  static const String _kGoalDate = 'scare_coin.reward.goal_date';

  /// 待结算会话队列（2026-10-17 审计 P2）。
  ///
  /// 存在的理由：`learning` 的 scope 在 `scare_coin` **外层**，会话状态层
  /// 拿不到账本 ⇒ 没法在「答完最后一题」那一刻直接发币。而原先的发币只挂在
  /// 完成页的 post-frame 回调上 ⇒ 完成页没挂载（挂载失败/应用被杀）就静默丢奖。
  /// 现在会话完成时只做一次**不需要账本**的登记（写 SP），发币交给能读到账本的
  /// 页面，或下次启动时补发。
  static const String pendingKey = 'scare_coin.reward.pending_sessions';

  /// 队列上限：异常情况下（发币持续失败）不让它无限增长；超出丢最旧并上报。
  static const int pendingCap = 5;

  /// 审计 R4/R5（2026-11-16）：队列读-改-写互斥锁。enqueue 与 settle 收尾合并
  /// 共用此锁，杜绝「并发登记落在收尾重读与回写之间被整段覆盖」的残留竞态。
  static Future<void> _queueMutex = Future<void>.value();

  static Future<T> _withQueueLock<T>(Future<T> Function() action) {
    final prev = _queueMutex;
    final completer = Completer<void>();
    _queueMutex = completer.future;
    return prev.then((_) => action()).whenComplete(() => completer.complete());
  }

  static int _idSeq = 0;

  /// 唯一条目 id：时间戳 + 进程内自增序号，保证同毫秒两次登记也不字节级相同
  /// （修 R5：旧实现按字符串去重会误滤相同的并发新登记）。
  static String _newEntryId() => '${DateTime.now().microsecondsSinceEpoch}-${_idSeq++}';

  /// 登记一次「会话已完成、待发币」。**不需要账本**，只写 SP。
  static Future<void> enqueuePendingSession({required int wordsLearned, required bool dailyGoalAchieved}) async {
    await _withQueueLock(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload(); // 取最新队列（含其他 isolate/页面刚写入的条目）。
        final list = _readPending(prefs)
          ..add(
            jsonEncode({
              'id': _newEntryId(),
              'wordsLearned': wordsLearned,
              'dailyGoalAchieved': dailyGoalAchieved,
              // 用户反馈修复（2026-11-14）：记录归属日，跨天补发时目标奖作废，
              // 避免「昨天达标今天领 +20、今天真实达标反而领不到」。
              'date': DateTime.now().toIso8601String().substring(0, 10),
            }),
          );
        final kept = list.length > pendingCap ? list.sublist(list.length - pendingCap) : list;
        if (list.length > kept.length) {
          reportSwallowedError(
            '待结算会话超上限，丢弃最旧 ${list.length - kept.length} 条',
            StateError('pending reward overflow'),
            StackTrace.current,
          );
        }
        if (!await prefs.setString(pendingKey, jsonEncode(kept))) {
          reportSwallowedError('会话奖励登记失败（本次奖励可能丢失）', StateError('pending write failed'), StackTrace.current);
        }
      } catch (e, s) {
        reportSwallowedError('会话奖励登记失败（本次奖励可能丢失）', e, s);
      }
    });
  }

  static List<String> _readPending(SharedPreferences prefs) {
    final raw = prefs.getString(pendingKey);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (e, s) {
      reportSwallowedError('待结算会话队列损坏（按空处理）', e, s);
    }
    return <String>[];
  }

  /// 结算全部待结算会话（幂等；进程内串行）。返回累计发出币数。
  ///
  /// 用户反馈修复（2026-11-14）：**逐条移除已成功条目**，只保留失败条目下次
  /// 重试。旧实现「任一条失败保留整队」会让已成功条目在重试时再次发币
  /// （`settleSession` 的每日上限只限总量，不防同会话重发）。
  Future<SessionRewardResult> settlePendingSessions() async {
    if (_draining) return const SessionRewardResult(totalGranted: 0);
    _draining = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _readPending(prefs);
      if (list.isEmpty) return const SessionRewardResult(totalGranted: 0);

      var granted = 0;
      var goalJustAchieved = false;
      final remaining = <String>[];
      // 审计 R5：按唯一 id 标记已处理（而非整条字符串），同载荷的并发新登记
      // 不会被误滤。旧格式条目无 id 时回退用整条字符串作键。
      final processedKeys = <String>{};
      for (final entry in list) {
        String key = entry;
        try {
          final map = jsonDecode(entry) as Map<String, dynamic>;
          final id = map['id'] as String?;
          if (id != null) key = id;
          // 审计 R6：用幂等发币（eventKey=条目 id+奖励类型）。条目内「会话奖已发、
          // 目标奖失败」整条重试时，已发的会话奖被 grantOnce 跳过，不重复 +5。
          final result = await _settleEntryIdempotent(
            entryId: id,
            wordsLearned: (map['wordsLearned'] as num?)?.toInt() ?? 0,
            dailyGoalAchieved: (map['dailyGoalAchieved'] as bool?) ?? false,
            achievedDate: (map['date'] as String?),
          );
          granted += result.totalGranted;
          goalJustAchieved = goalJustAchieved || result.goalJustAchieved;
        } on _PartialRewardFailure catch (e) {
          // 审计 R6：会话奖已实发、目标奖失败——已发部分计入本次，条目保留重试目标奖。
          granted += e.partialGranted;
          remaining.add(entry);
          reportSwallowedError('待结算会话目标奖失败（会话奖已发，保留重试目标奖）', e.cause, StackTrace.current);
        } catch (e, s) {
          remaining.add(entry);
          reportSwallowedError('待结算会话发币失败（保留该条下次重试）', e, s);
        }
        processedKeys.add(key);
      }
      // 审计 R4：收尾合并入互斥锁——reload 重读最新队列，仅移除本次已处理 id，
      // 保留期间并发新登记（与 enqueue 共用锁，闭合「重读与回写之间」残留窗）。
      await _withQueueLock(() async {
        await prefs.reload();
        final latest = _readPending(prefs);
        final kept = latest.where((e) {
          String k = e;
          try {
            final id = (jsonDecode(e) as Map<String, dynamic>)['id'] as String?;
            if (id != null) k = id;
          } catch (_) {
            // 吞错豁免: 坏条目按整条字符串键处理。
          }
          return !processedKeys.contains(k);
        }).toList()..addAll(remaining);
        if (kept.isEmpty) {
          await prefs.remove(pendingKey);
        } else {
          await prefs.setString(pendingKey, jsonEncode(kept));
        }
      });
      return SessionRewardResult(totalGranted: granted, goalJustAchieved: goalJustAchieved);
    } finally {
      _draining = false;
    }
  }

  static bool _draining = false;

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  /// 审计 R6（2026-11-16）：队列条目幂等结算。与 [settleSession] 同口径（每日
  /// 会话上限/目标当日一次/跨天作废），但发币走 [ScareCoinStore.grantOnce]，
  /// eventKey=条目 id+奖励类型——条目内部分成功后整条重试不重复发币。
  /// [entryId] 为 null（旧格式条目）时回退普通 grant（无幂等键，保持旧行为）。
  Future<SessionRewardResult> _settleEntryIdempotent({
    required String? entryId,
    required int wordsLearned,
    required bool dailyGoalAchieved,
    String? achievedDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final goalEligible = dailyGoalAchieved && (achievedDate == null || achievedDate == today);
    var granted = 0;
    var goalJustAchieved = false;

    // 返回 true=本次实发；false=幂等跳过（该 eventKey 已发过，重试不重发）。
    Future<bool> pay(int delta, String reason, String suffix) async {
      if (entryId == null) {
        await _store.grant(delta: delta, reason: reason);
        return true;
      }
      final balance = await _store.grantOnce(delta: delta, reason: reason, eventKey: 'reward:$entryId:$suffix');
      return balance != null;
    }

    // 1) 会话完成奖励（每日限量）
    if (wordsLearned >= _sessionMinWords) {
      if (prefs.getString(_kSessionDate) != today) {
        await prefs.setInt(_kSessionCount, 0);
        await prefs.setString(_kSessionDate, today);
      }
      final count = prefs.getInt(_kSessionCount) ?? 0;
      if (count < _sessionDailyCap) {
        if (!await prefs.setInt(_kSessionCount, count + 1)) {
          return SessionRewardResult(totalGranted: granted, goalJustAchieved: goalJustAchieved);
        }
        try {
          if (await pay(_sessionReward, '学习完成', 'session')) granted += _sessionReward;
        } catch (e) {
          if (!await prefs.setInt(_kSessionCount, count)) {
            reportSwallowedError('会话奖励回滚：计数写失败（当日名额可能少计一次）', e, StackTrace.current);
          }
          rethrow;
        }
      }
    }

    // 2) 每日目标达成奖励（当日仅一次）
    if (goalEligible && prefs.getString(_kGoalDate) != today) {
      if (!await prefs.setString(_kGoalDate, today)) {
        return SessionRewardResult(totalGranted: granted, goalJustAchieved: goalJustAchieved);
      }
      try {
        if (await pay(_goalReward, '今日目标达成', 'goal')) {
          granted += _goalReward;
          goalJustAchieved = true;
        }
      } catch (e) {
        if (!await prefs.remove(_kGoalDate)) {
          reportSwallowedError('目标奖励回滚：标记清除失败（当日可能重复发奖）', e, StackTrace.current);
        }
        // 会话奖可能已实发（granted>0）：携带已发部分上抛，结算循环计入本次结果。
        throw _PartialRewardFailure(granted, e);
      }
    }

    return SessionRewardResult(totalGranted: granted, goalJustAchieved: goalJustAchieved);
  }

  /// 会话结束统一结算。
  ///
  /// [wordsLearned] 本会话实际学过的词数；[dailyGoalAchieved] 截至本次结算
  /// 今日已学是否达到每日目标。幂等性由调用方保证（每会话只调用一次）。
  Future<SessionRewardResult> settleSession({
    required int wordsLearned,
    required bool dailyGoalAchieved,
    String? achievedDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    // 用户反馈修复（2026-11-14）：目标奖只认归属日=结算日；跨天补发作废，
    // 不占用今日标记（今日真实达标仍可领）。
    final goalEligible = dailyGoalAchieved && (achievedDate == null || achievedDate == today);
    var granted = 0;
    var goalJustAchieved = false;

    // 1) 会话完成奖励（每日限量）
    if (wordsLearned >= _sessionMinWords) {
      if (prefs.getString(_kSessionDate) != today) {
        // 写序：先清计数再翻日期。反序崩溃在两写之间会留下「新日期+旧计数」，
        // 当日剩余次数被错误压低；正序崩溃窗口只会多清一次计数（幂等无害）。
        await prefs.setInt(_kSessionCount, 0);
        await prefs.setString(_kSessionDate, today);
      }
      final count = prefs.getInt(_kSessionCount) ?? 0;
      if (count < _sessionDailyCap) {
        // 先持久化防重标记（SP 写失败返回 false 时不发币），发币失败回滚标记：
        // 反序（先发币后写标记）在标记写失败时会让同日下一会话重复发奖。
        if (!await prefs.setInt(_kSessionCount, count + 1)) {
          return SessionRewardResult(totalGranted: granted, goalJustAchieved: goalJustAchieved);
        }
        try {
          await _store.grant(delta: _sessionReward, reason: '学习完成');
        } catch (e) {
          // 回滚写失败只上报（此时 rethrow 的语义是「发币失败」，不能被覆盖）：
          // 名额可能被烧一次，留在遥测里对账。
          if (!await prefs.setInt(_kSessionCount, count)) {
            reportSwallowedError('会话奖励回滚：计数写失败（当日名额可能少计一次）', e, StackTrace.current);
          }
          rethrow;
        }
        granted += _sessionReward;
      }
    }

    // 2) 每日目标达成奖励（当日仅一次）
    if (goalEligible && prefs.getString(_kGoalDate) != today) {
      if (!await prefs.setString(_kGoalDate, today)) {
        return SessionRewardResult(totalGranted: granted, goalJustAchieved: goalJustAchieved);
      }
      try {
        await _store.grant(delta: _goalReward, reason: '今日目标达成');
      } catch (e) {
        if (!await prefs.remove(_kGoalDate)) {
          reportSwallowedError('目标奖励回滚：标记清除失败（当日可能重复发奖）', e, StackTrace.current);
        }
        rethrow;
      }
      granted += _goalReward;
      goalJustAchieved = true;
    }

    return SessionRewardResult(totalGranted: granted, goalJustAchieved: goalJustAchieved);
  }
}
