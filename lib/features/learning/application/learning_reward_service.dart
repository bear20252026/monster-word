// 学习行为发币服务 — 尖叫币经济与学习行为挂钩。
//
// 设计原则：
// 1. 只奖不罚：答错、中断均不扣币，保持正向激励。
// 2. 防刷：所有奖励按自然日键控（SharedPreferences），跨天自动清零。
//    - 会话完成奖励：每会话一次（由调用方保证），每自然日最多 _sessionDailyCap 次。
//    - 目标达成奖励：每自然日至多一次（日期标记）。
// 3. 诚实入账：走 ScareCoinStore.grant()，账本 reason 为中文，历史页直接可读。
import 'package:shared_preferences/shared_preferences.dart';

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
        await prefs.setString(_kSessionDate, today);
        await prefs.setInt(_kSessionCount, 0);
      }
      final count = prefs.getInt(_kSessionCount) ?? 0;
      if (count < _sessionDailyCap) {
        await _store.grant(delta: _sessionReward, reason: '学习完成');
        await prefs.setInt(_kSessionCount, count + 1);
        granted += _sessionReward;
      }
    }

    // 2) 每日目标达成奖励（当日仅一次）
    if (dailyGoalAchieved && prefs.getString(_kGoalDate) != today) {
      await _store.grant(delta: _goalReward, reason: '今日目标达成');
      await prefs.setString(_kGoalDate, today);
      granted += _goalReward;
      goalJustAchieved = true;
    }

    return SessionRewardResult(totalGranted: granted, goalJustAchieved: goalJustAchieved);
  }
}
