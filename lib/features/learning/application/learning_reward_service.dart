// 学习行为发币服务 — 尖叫币经济与学习行为挂钩。
//
// 设计原则：
// 1. 只奖不罚：答错、中断均不扣币，保持正向激励。
// 2. 防刷：所有奖励按自然日键控（SharedPreferences），跨天自动清零。
//    - 会话完成奖励：每会话一次（由调用方保证），每自然日最多 _sessionDailyCap 次。
//    - 目标达成奖励：每自然日至多一次（日期标记）。
// 3. 诚实入账：走 ScareCoinStore.grant()，账本 reason 为中文，历史页直接可读。
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';

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

  /// 登记一次「会话已完成、待发币」。**不需要账本**，只写 SP。
  static Future<void> enqueuePendingSession({required int wordsLearned, required bool dailyGoalAchieved}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _readPending(prefs)
        ..add(jsonEncode({'wordsLearned': wordsLearned, 'dailyGoalAchieved': dailyGoalAchieved}));
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
  /// 任一条失败就**保留整个队列**下次重试 —— 宁可重复尝试（`settleSession`
  /// 有每日上限，不会超发），也不要静默丢掉用户的奖励。
  Future<SessionRewardResult> settlePendingSessions() async {
    if (_draining) return const SessionRewardResult(totalGranted: 0);
    _draining = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _readPending(prefs);
      if (list.isEmpty) return const SessionRewardResult(totalGranted: 0);

      var granted = 0;
      var goalJustAchieved = false;
      var failed = false;
      for (final entry in list) {
        try {
          final map = jsonDecode(entry) as Map<String, dynamic>;
          final result = await settleSession(
            wordsLearned: (map['wordsLearned'] as num?)?.toInt() ?? 0,
            dailyGoalAchieved: (map['dailyGoalAchieved'] as bool?) ?? false,
          );
          granted += result.totalGranted;
          goalJustAchieved = goalJustAchieved || result.goalJustAchieved;
        } catch (e, s) {
          failed = true;
          reportSwallowedError('待结算会话发币失败（保留队列下次重试）', e, s);
        }
      }
      if (!failed) await prefs.remove(pendingKey);
      return SessionRewardResult(totalGranted: granted, goalJustAchieved: goalJustAchieved);
    } finally {
      _draining = false;
    }
  }

  static bool _draining = false;

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  /// 会话结束统一结算。
  ///
  /// [wordsLearned] 本会话实际学过的词数；[dailyGoalAchieved] 截至本次结算
  /// 今日已学是否达到每日目标。幂等性由调用方保证（每会话只调用一次）。
  Future<SessionRewardResult> settleSession({required int wordsLearned, required bool dailyGoalAchieved}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
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
    if (dailyGoalAchieved && prefs.getString(_kGoalDate) != today) {
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
