// 第四轮审计 M4（2026-11-18）：会话完成上报共享编排下沉 application。
//
// 背景：LearningSessionState._reportSessionCompleted 与
// ReviewSessionState._reportSessionCompletedIfDone 各自内联一份逐行同构的
// 「会话数 + 答题词次/答对数 + 一局正确率任务」上报。两处答对数口径完全一致
// （(answered - wrong).clamp(0, answered)），正确率都走 missions 域的
// sessionAccuracyPercent 单源。抽到 application 共享，State 只保留各自的
// 触发时机与独有副作用（学习侧的待结算奖励登记）。
//
// 幂等：report() 一局只生效一次（首次调用置位，后续直接返回）。学习侧原靠
// _sessionCompletionReported 显式闸、复习侧原靠 _completeStep 每题至多一次 +
// done>=total 后 currentWord=null 拒重入的自然守卫；收敛后统一为显式幂等，
// 行为不变（两侧本就一局一报）。reset() 供开新局时清闸。
//
// 纯 Dart（不 import flutter/*）：可整表驱动单测覆盖，与 executor/planner 同款。
import 'dart:async';

import 'package:word_app/features/missions/application/daily_mission_store.dart';
import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';

/// 会话完成上报器：一局学习/复习走完时记一次会话数、答题词次与答对数，
/// 并按同一口径登记「一局正确率」每日任务。
class SessionCompletionReporter {
  SessionCompletionReporter({this.usageStats, this.dailyMissions});

  final UsageStatsRecorder? usageStats;
  final DailyMissionStore? dailyMissions;

  bool _reported = false;

  /// 本局是否已上报（供状态层观察/测试）。
  bool get hasReported => _reported;

  /// 开新局时清幂等闸（loadBook / 收藏新局 / 错题复习 / 复习 initialize 共用）。
  void reset() => _reported = false;

  /// 上报一次会话完成。[answered] 本局答题词次，[wrong] 其中答错词次。
  ///
  /// 答对数 = answered - wrong（钳到 [0, answered]），与两会话页 accuracy 同口径；
  /// 正确率任务走 sessionAccuracyPercent 单源（floor，answered<=0 返回 null 不判定）。
  /// 一局只生效一次：重复调用（走完队列与中途收工共用触发点）直接返回。
  void report({required int answered, required int wrong}) {
    if (_reported) return;
    _reported = true;
    final correct = (answered - wrong).clamp(0, answered);
    final recorder = usageStats;
    if (recorder != null) {
      unawaited(recorder.recordStudySession());
      unawaited(recorder.recordAnswers(reviewed: answered, correct: correct));
    }
    // M2/D1：一局正确率 ≥80%（学习与复习同计；错题口径与上方 usageStats 一致）。
    final missions = dailyMissions;
    final percent = sessionAccuracyPercent(answered: answered, correct: correct);
    if (missions != null && percent != null) unawaited(missions.recordSessionAccuracyPercent(percent));
  }
}
