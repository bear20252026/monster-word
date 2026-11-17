import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/calendar_days.dart';
import 'package:word_app/core/utils/monster_identity_prefs.dart';
import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/learning/application/learning_reward_service.dart';
import 'package:word_app/features/learning/application/onboarding_gate_store.dart';
import 'package:word_app/features/scare_coin/application/protection_card.dart';

/// 首页首帧启动仪式编排（结构修复步骤5b / M4：从 app.dart `_HomeShellState`
/// 外移的业务）。壳层只保留「首帧回调 + mounted 判定 + 演出呈现」，
/// 判定/持久化/发奖全部在此：
///
/// 1. [drainPendingRewards]：补发「已完成但没结算」的会话奖励（2026-10-17 审计 P2）。
///    会话完成时只登记（写 SP，不需要账本），若应用在完成页结算前被杀，
///    这笔奖励靠这里在下次启动补发——否则会静默丢掉。
/// 2. [runReunionRitual]：蓝图 W4 回家仪式——距上次打开 ≥3 天（有旧访问记录）
///    → 门缝演出 + 免费送断签保护卡；首次使用 → 三步引导。无论是否触发都刷新
///    last_visit 为今天。
///
/// 演出（showReunionOverlay / showOnboardingPromiseDialog / HapticsGate）经回调
/// 注入：application 层不依赖 presentation（R3），壳层传入已绑定 context 的闭包。
class HomeStartupCoordinator {
  HomeStartupCoordinator({
    required this.lastVisitPrefKey,
    required this.rewards,
    required this.protection,
    required this.showReunion,
    required this.showOnboarding,
    this.isMounted = _alwaysMounted,
    this.now,
  });

  /// 上次访问日期 SP key（由壳层从 ReunionOverlay.lastVisitPrefKey 传入，
  /// 避免 application 依赖 widgets 演出组件）。
  final String lastVisitPrefKey;

  /// 待结算会话队列结算器（壳层用账本构造；最小装配无账本时传 null 跳过）。
  final LearningRewardService? rewards;

  /// 回家礼保护卡发放端口；未注入（最小装配）时静默跳过发放。
  final ProtectionCard? protection;

  /// 回家演出呈现回调（壳层绑定 context + 触觉 + 浮层）。
  final void Function(int absentDays) showReunion;

  /// 首启三步引导呈现回调（壳层绑定 context 弹窗，await 用户关闭/跳过）。
  final Future<void> Function() showOnboarding;

  /// 壳层 mounted 判定：异步 gap 后防对已卸载页面演出。
  final bool Function() isMounted;

  /// 时钟注入（测试用）；缺省 DateTime.now()。
  final DateTime Function()? now;

  static bool _alwaysMounted() => true;

  DateTime _now() => (now ?? DateTime.now)();

  /// 补发待结算会话奖励。[rewards] 为 null（最小装配没有账本 scope）时直接
  /// 跳过——队列留着，真机上下次启动照常补发，不当故障上报。
  Future<void> drainPendingRewards() async {
    final rewards = this.rewards;
    if (rewards == null || !isMounted()) return;
    try {
      await rewards.settlePendingSessions();
    } catch (e, s) {
      reportSwallowedError('启动补发待结算奖励失败（下次启动重试）', e, s);
    }
  }

  /// 回家仪式判定 + 首启引导分流。返回时 last_visit 已刷新为今天。
  Future<void> runReunionRitual() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = MonsterSpeech.dayKeyOf(_now());
      final last = prefs.getString(lastVisitPrefKey);
      await prefs.setString(lastVisitPrefKey, today);
      if (!isMounted()) return;
      if (last == null) {
        // 首次使用：先讲三步与一句承诺（只此一次，可跳过；老用户升级不打扰）。
        await _maybeShowOnboarding();
        return;
      }
      final lastDate = DateTime.tryParse(last);
      if (lastDate == null) return;
      // 日历日差（DST 安全）：绝对时长差在夏令时周会少算一天，误杀 3 天回归礼。
      final absent = calendarDaysBetween(lastDate, _now());
      if (absent < 3) return;
      showReunion(absent);
      // 回家礼：断签保护卡 ×1（走既有 API；满额抛错/失败不阻断演出）。
      final protection = this.protection;
      if (protection == null) {
        // 第三轮 T31：端口缺席不再静默——原壳层实现在演出后 read 抛错走 catch
        // 上报，外移时退化为无声 return（可观测性退化）。生产 store 恒在，
        // 此分支仅最小装配/测试触达，上报留痕便于发现装配遗漏。
        reportSwallowedError('回家礼保护卡未发放（保护卡端口未注入）', StateError('protection port absent'), StackTrace.current);
        return;
      }
      try {
        await protection.addProtection(count: 1, reason: '回家礼');
      } catch (e, s) {
        reportSwallowedError('回家礼保护卡未发放（发放失败或库存已满）', e, s);
      }
    } catch (e, s) {
      reportSwallowedError('回家仪式判定失败', e, s);
    }
  }

  /// 首启三步角色对话 + 一句承诺：只出现一次，关闭/跳过都落标。
  /// 已破壳的用户在命名仪式里已串演过（闸门合并），这里不再二弹；
  /// 本分支只兜底「已破壳但引导标丢失」与老版本升级路径。
  Future<void> _maybeShowOnboarding() async {
    try {
      const gate = OnboardingGateStore();
      if (gate.done) return;
      if (await MonsterIdentityPrefs.hatched) return;
      if (!isMounted()) return;
      await showOnboarding();
      if (!await gate.markDone()) {
        reportSwallowedError('首启引导标记写入失败', StateError('setOnboardingDone returned false'), StackTrace.current);
      }
    } catch (e, s) {
      reportSwallowedError('首启引导展示失败', e, s);
    }
  }
}
