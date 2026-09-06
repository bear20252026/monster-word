// Monster Word — 今日进度单一事实源（TodayProgressStore）
//
// 修复历史双目标键混乱：`daily_learn_goal`(A) 与 `daily_new_words_v1`(B)
// 曾是两套互不同步的「每日目标」。本 store 收敛为：
// - 目标唯一源：UserPreferences.dailyGoal（A，队列限额/达标判定都用它）
// - 已学唯一源：AppPreferences.todayLearned（跨天清零集中在此，取代散落各处）
// - 待复习：由 ReviewScheduleReader 经 sync 注入 FromApp 上层
// 全站页面订阅本 store，改目标走 setGoal() → notifyListeners() 即时同步。

import 'package:flutter/foundation.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';

class TodayProgressStore extends ChangeNotifier {
  TodayProgressStore();

  static bool _persistentStateInitialized = false;

  /// 在 bootstrap 中、页面/Provider 创建前串行完成旧目标迁移，避免首帧默认 10 竞态。
  static Future<void> initializePersistentState() async {
    if (_persistentStateInitialized) return;
    final app = AppPreferences();
    final user = UserPreferences();
    if (app.isTodayGoalMigrated) {
      _persistentStateInitialized = true;
      return;
    }
    final legacy = app.getDailyNewWords();
    final current = user.getDailyGoal();
    // B 非默认且 A 仍为默认：认为旧设置页值是用户意图，迁移到真实目标 A。
    if (legacy != 10 && current == 10) {
      await user.setDailyGoal(legacy);
    }
    await app.markTodayGoalMigrated();
    _persistentStateInitialized = true;
  }

  int _due = 0;
  int _lastLearned = -1;
  int _lastGoal = -1;
  String _checkedDate = '';

  // ── 目标（唯一源：daily_learn_goal，A） ──
  int get goal => UserPreferences().getDailyGoal();

  /// 今日已学（唯一源：todayLearned；跨天清零由 sync 集中处理）。
  int get learned => AppPreferences().getTodayLearned();

  /// 剩余待学（目标 − 已学，钳到 ≥0）。
  int get remaining => goal > 0 ? (goal - learned).clamp(0, goal).toInt() : 0;

  /// 今日达标。
  bool get achieved => goal > 0 && learned >= goal;

  /// 待复习（到期卡片数，FSRS）。
  int get due => _due;

  /// 学习会话/复习调度变化时由上层 Proxy 调用：刷新已学(含跨天清零)与待复习，
  /// 任一变化才通知，避免无谓重建。
  void sync({required int due, DateTime? now}) {
    final t = now ?? DateTime.now();
    final learned = _resetIfNewDay(t);
    final goal = this.goal;
    final changed = due != _due || learned != _lastLearned || goal != _lastGoal;
    _due = due;
    _lastLearned = learned;
    _lastGoal = goal;
    if (changed) notifyListeners();
  }

  /// 用户修改每日目标：写 A 键并全局通知。收敛首页档位/滚轮与设置页共用此入口。
  Future<void> setGoal(int value) async {
    final clamped = value.clamp(1, 200);
    await UserPreferences().setDailyGoal(clamped);
    _lastGoal = clamped;
    notifyListeners();
  }

  /// 跨天清零（集中到本 store，取代过去只在学习会话里清零导致的错乱）。
  int _resetIfNewDay(DateTime now) {
    final date = _date(now);
    if (_checkedDate == date) return AppPreferences().getTodayLearned();
    _checkedDate = date;
    final savedDate = AppPreferences().getTodayLearnedDate();
    if (savedDate != date) {
      // 跨天：清零已学并落当天日期（与 session 口径一致）
      AppPreferences().setTodayLearned(0, date: date);
      return 0;
    }
    return AppPreferences().getTodayLearned();
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
