// 怪兽陪伴层的状态（companion/presentation）。
//
// 职责边界（红线）：本类**只**决定「演什么、说什么」，不写任何持久化状态。
// 奖励/羁绊/学习记录各自有主，演出层无权改数据 —— 结构上成立，不靠自觉。
//
// 文案不在这里另造一套：全部走 [MonsterSpeech]（台词单一来源，含每日主动预算
// ≤3 条/日与组内去重）。没有对应槽位的场景**宁可不说**，也不就地写死文案。
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

  /// 推一个事实事件。返回是否发生了场景切换（调用方可据此决定是否播动效）。
  @override
  bool dispatch(MonsterEvent event, {DateTime? at}) {
    final next = _graph.dispatch(event, at: at);
    if (next == null) return false;
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
      // 「三词小组」没有现成文案槽。宁可不说，也不在 companion 里另造一套文案
      // —— 台词单一来源在 monster_speech，加文案要改那张表并补测试。
      MonsterInitiative.proposeThreeWordGroup => null,
    };
    if (slot == null) return null;
    if (!_speech.canSpeak()) return null;
    _speech.consumeBudget();
    return _speech.pick(slot, vars: {'due': input.dueCount});
  }
}
