// 怪兽陪伴层的状态（companion/presentation）。
//
// 职责边界（红线）：本类**只**决定「演什么、说什么」，不写任何持久化状态。
// 奖励/羁绊/学习记录各自有主，演出层无权改数据 —— 结构上成立，不靠自觉。
//
// 文案不在这里另造一套：全部走 [MonsterSpeech]（台词单一来源，含每日主动预算
// ≤3 条/日与组内去重）。没有对应槽位的场景**宁可不说**，也不就地写死文案。
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/features/companion/application/monster_companion_port.dart';
import 'package:word_app/core/utils/monster_event.dart';
import 'package:word_app/core/utils/monster_initiative.dart';
import 'package:word_app/core/utils/monster_scene.dart';
import 'package:word_app/features/companion/domain/monster_scene_graph.dart';

class MonsterCompanionState extends ChangeNotifier implements MonsterCompanionController {
  MonsterCompanionState({MonsterSceneGraph? graph, MonsterSpeech? speech})
    : _graph = graph ?? MonsterSceneGraph(),
      _speech = speech ?? MonsterSpeech();

  final MonsterSceneGraph _graph;
  final MonsterSpeech _speech;

  MonsterInitiativeDecision? _initiative;
  String? _line;

  /// 当前场景（渲染用）。
  @override
  MonsterScene get scene => _graph.current;

  /// 它此刻主动想做的事；null = 没有值得说的（不硬凑）。
  MonsterInitiativeDecision? get initiative => _initiative;

  /// 气泡文案；null = 此刻不说话（没话说 / 该场景无文案槽 / 今日主动预算用尽）。
  @override
  String? get line => _line;

  /// 连续答错计数（只在这里维护）。
  ///
  /// 页面只报「对/错」两个事实，**升级成「连续困难」由本层判断** —— 否则每个页面
  /// 都要自己数一遍连续错，迟早有一处数错（这也是「事件只报事实」的用意）。
  int _consecutiveWrong = 0;

  /// 一次性演出的到期计时器（只在演出期间存在，最长 3s）。
  Timer? _expiryTimer;

  /// 推一个事实事件。返回是否发生了场景切换（调用方可据此决定是否播动效）。
  @override
  bool dispatch(MonsterEvent event, {DateTime? at}) {
    final now = at ?? DateTime.now();
    // 先让过期的一次性演出回落，再判本次事件（否则「上一条提示还挂着」会误判优先级）。
    final rolledBack = _rollIfExpired(now);

    var escalated = false;
    if (event == MonsterEvent.answerCorrect) {
      _consecutiveWrong = 0;
    } else if (event == MonsterEvent.answerWrong) {
      _consecutiveWrong++;
      if (_consecutiveWrong == MonsterInitiativeThresholds.hardStreak) {
        escalated = _graph.dispatch(MonsterEvent.hardStreak, at: now) != null;
      }
    }

    final next = _graph.dispatch(event, at: now);
    final changed = next != null || escalated || rolledBack;
    if (!changed) return false;
    _scheduleExpiry(now);
    notifyListeners();
    return true;
  }

  /// 定时推进：一次性演出到点回落。返回是否切换。
  @override
  bool tick({DateTime? at}) {
    final next = _graph.tick(at: at);
    if (next == null) return false;
    notifyListeners();
    return true;
  }

  /// 当前场景若是一次性演出且已到点，回落到基础场景。返回是否发生回落。
  bool _rollIfExpired(DateTime now) {
    final entered = _graph.enteredAt;
    if (entered == null) return false;
    final spec = specOf(_graph.current);
    if (!spec.isOneShot) return false;
    if (now.difference(entered) < spec.hold) return false;
    return _graph.tick(at: now) != null;
  }

  /// 为当前一次性演出挂一个到期回调（演出结束后自动回落，不必等下一个事件）。
  void _scheduleExpiry(DateTime now) {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final spec = specOf(_graph.current);
    if (!spec.isOneShot) return;
    final entered = _graph.enteredAt;
    if (entered == null) return;
    final remaining = spec.hold - now.difference(entered);
    if (remaining <= Duration.zero) return;
    _expiryTimer = Timer(remaining, () {
      _expiryTimer = null;
      if (_graph.tick() != null) notifyListeners();
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    super.dispose();
  }

  /// 用最新事实刷新「它想说什么」。
  ///
  /// 同一条建议不重复刷新文案：否则每次 rebuild 都换一句话，看起来像在抖。
  @override
  void refreshInitiative(MonsterInitiativeInput input) {
    final decision = pickInitiative(input);
    if (decision == null) {
      if (_initiative == null) return;
      _initiative = null;
      _line = null;
      notifyListeners();
      return;
    }
    // 同类建议：只更新数据（reason/到期数可能变了），不换台词。
    if (_initiative?.initiative == decision.initiative) {
      _initiative = decision;
      return;
    }
    _initiative = decision;
    _line = _speak(decision, input);
    notifyListeners();
  }

  String? _speak(MonsterInitiativeDecision decision, MonsterInitiativeInput input) {
    final slot = switch (decision.initiative) {
      MonsterInitiative.proposeReview => SpeechSlot.needReview,
      MonsterInitiative.proposeCheckin => SpeechSlot.needCheckin,
      MonsterInitiative.welcomeBack => SpeechSlot.welcomeBack,
      // 连续答错 → 提议只学三个词。文案在 monster_speech 那张表里（单一来源），
      // 这里只负责把决策翻成槽位。
      MonsterInitiative.proposeThreeWordGroup => SpeechSlot.suggestThreeWordGroup,
    };
    if (!_speech.canSpeak()) return null;
    _speech.consumeBudget();
    return _speech.pick(slot, vars: {'due': input.dueCount});
  }
}
