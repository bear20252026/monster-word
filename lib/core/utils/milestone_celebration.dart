// P2-8（架构审计 2026-11-12）：金币/连胜里程碑庆祝编排（单一真相）。
//
// 此前 learn_page 与 treasure_checkin_page 各有一份逐行相同的 _maybeCelebrateMilestone
// （判定链 readBaseline→crossedMilestone→基线化不补演 + milestone 音 + heavy 触觉 +
// 探头台词 + show 成功才落标），checkin 还有第三份连胜变体。判定规则本已在
// MilestoneGuard 共享，缺的是「庆祝编排」——本服务收口编排，页面只传入余额/连胜值。
//
// 演出组件（探头浮层/粒子）驱动异构（AnimationController/Ticker/CustomPainter），
// 合并为统一 CelebrationEngine 属后续专项；本服务先消除编排重复。
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/haptics_gate.dart';
import 'package:word_app/core/utils/milestone_guard.dart';
import 'package:word_app/core/utils/sfx.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/widgets/monster_peek_overlay.dart';

class MilestoneCelebration {
  MilestoneCelebration._();

  /// 金币里程碑庆祝：余额跨档时探头 + 音效 + 触觉，成功才落标。
  ///
  /// [isMounted] 由调用方传入（页面 mounted），异步取 prefs 后复查防越界演出。
  /// 首次基线化（readBaseline 返回 null）不补演；未跨档不演；探头被串行占用
  /// （show 返回 false）则不落标，下次余额变动再试。
  static Future<void> celebrateCoin({
    required BuildContext context,
    required int newBalance,
    required bool Function() isMounted,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final celebrated = await MilestoneGuard.readBaseline(prefs, newBalance);
      if (celebrated == null) return; // 首次基线化不补演
      final crossed = MilestoneGuard.crossedMilestone(celebrated, newBalance);
      if (crossed == null) return;
      if (!isMounted()) return;
      SfxPlayer.fire(Sfx.milestone);
      HapticsGate.play(HapticCue.heavy);
      // ignore: use_build_context_synchronously — 上方 isMounted() 回调即页面 mounted 守卫
      if (!MonsterPeekOverlay.show(context, phrase: '第 $crossed 枚尖叫币！钱包鼓鼓的！')) return;
      await _persistMarker(prefs, MilestoneGuard.lastCelebratedKey, crossed);
    } catch (e, s) {
      reportSwallowedError('里程碑庆祝失败', e, s);
    }
  }

  /// 连胜里程碑庆祝：连胜跨档时探头 + 音效 + 触觉，成功才落标。
  ///
  /// [key]/[thresholds]/[phraseFor] 由调用方传入——连胜的 SP 键与台词事实来源
  /// 在 checkin 域（streak_milestones.dart），core 不反向依赖 features（R-core），
  /// 故参数化而非内联。
  static Future<void> celebrateStreak({
    required BuildContext context,
    required int newStreak,
    required String key,
    required List<int> thresholds,
    required String Function(int milestone) phraseFor,
    required bool Function() isMounted,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final celebrated = await MilestoneGuard.readBaselineFor(prefs, key, newStreak);
      if (celebrated == null) return;
      final crossed = MilestoneGuard.crossedThreshold(celebrated, newStreak, thresholds);
      if (crossed == null) return;
      if (!isMounted()) return;
      SfxPlayer.fire(Sfx.milestone);
      HapticsGate.play(HapticCue.heavy);
      // ignore: use_build_context_synchronously — 上方 isMounted() 回调即页面 mounted 守卫
      if (!MonsterPeekOverlay.show(context, phrase: phraseFor(crossed))) return;
      await _persistMarker(prefs, key, crossed);
    } catch (e, s) {
      reportSwallowedError('连胜里程碑庆祝失败', e, s);
    }
  }

  /// 落标：写失败上报（内存庆祝已发生，标记下次重试，不静默吞）。
  static Future<void> _persistMarker(SharedPreferences prefs, String key, int value) async {
    final saved = await prefs.setInt(key, value);
    if (!saved) {
      reportSwallowedError('里程碑庆祝标记写入失败', StateError('setInt($key=$value) returned false'), StackTrace.current);
    }
  }
}
