// 怪兽演出场景图（companion 域，纯 Dart 零依赖）。
//
// 结构取自 VPet 的 Graph 设计：**节点 = 场景，边 = 事件触发的条件转移**，
// 转移要同时满足优先级、冷却、不可打断三件事。VPet 用 C#/WPF 实现，这里是
// 按 Dart 重写的等价结构（不是移植源码）。
//
// 三条规则，按顺序判定（任一条不满足就不切换）：
//   1. **不可打断**：当前场景 `interruptible == false` 且仍在演出中 → 谁都不能抢。
//   2. **冷却**：目标场景距上次进入不足 `cooldown` → 不切（防频闪）。
//   3. **优先级**：当前场景仍在演出且优先级更高 → 不切。
//
// 时间全部显式传入（[at]），不读系统时钟 —— 纯函数式便于真跑断言。

import 'monster_event.dart';
import 'monster_scene.dart';

class MonsterSceneGraph {
  MonsterSceneGraph({DateTime Function()? now, MonsterScene base = MonsterScene.idle})
    : _now = now ?? DateTime.now,
      _base = base,
      _current = base,
      _enteredAt = null;

  final DateTime Function() _now;

  MonsterScene _base;
  MonsterScene _current;
  DateTime? _enteredAt;

  /// 各场景「上次进入」的时刻，冷却判定的锚点。
  final Map<MonsterScene, DateTime> _lastEntered = {};

  MonsterScene get current => _current;
  DateTime? get enteredAt => _enteredAt;
  MonsterScene get base => _base;

  /// 事件 → 目标场景。`null` = 这个事件不抢戏。
  ///
  /// 为什么答对/抚摸返回 null：这两件事**页面本身已经有反馈**（对勾、彩带、
  /// 小屋的反应动画）。演出层再抢一次会让怪兽变成「每点一下就抖一下」的
  /// 玩具，反而削弱陪伴感。陪伴的关键是「该出现时才出现」。
  static MonsterScene? sceneFor(MonsterEvent event) => switch (event) {
    MonsterEvent.sessionStarted => MonsterScene.preparing,
    MonsterEvent.answerCorrect => null,
    MonsterEvent.answerWrong => MonsterScene.hinting,
    MonsterEvent.hardStreak => MonsterScene.regrouping,
    MonsterEvent.sessionCompleted => MonsterScene.summarizing,
    MonsterEvent.returnedAfterGap => MonsterScene.greeting,
    MonsterEvent.fed => MonsterScene.celebrating,
    MonsterEvent.petted => null,
    MonsterEvent.reviewStarted => MonsterScene.carrying,
  };

  /// 推进一个事件。返回**切换后的场景**；`null` 表示画面不用动。
  MonsterScene? dispatch(MonsterEvent event, {DateTime? at}) {
    final target = sceneFor(event);
    if (target == null) return null;
    return _enter(target, at: at ?? _now());
  }

  /// 定时推进：一次性演出到点就回落到基础场景。返回新场景或 null。
  MonsterScene? tick({DateTime? at}) {
    final entered = _enteredAt;
    if (entered == null) return null;
    final spec = specOf(_current);
    if (!spec.isOneShot) return null;
    final now = at ?? _now();
    if (now.difference(entered) < spec.hold) return null;
    // 一次性演出结束 → 回落到基础场景（不是 idle：复习中应回到搬词卡态）。
    return _switchTo(_base, now);
  }

  /// 更新基础场景（由外部按心情/上下文决定，例如复习中 → carrying）。
  ///
  /// 只在当前没有一次性演出时立即生效，否则等 `tick()` 回落时采用新值。
  void setBase(MonsterScene scene, {DateTime? at}) {
    _base = scene;
    if (_enteredAt == null || !specOf(_current).isOneShot) {
      _switchTo(scene, at ?? _now());
    }
  }

  /// 强制立即进入（用于「首次进入页面」这类没有竞争者的场合）。
  void force(MonsterScene scene, {DateTime? at}) {
    _switchTo(scene, at ?? _now());
  }

  MonsterScene? _enter(MonsterScene target, {required DateTime at}) {
    final targetSpec = specOf(target);

    // 规则 1：不可打断的演出进行中，谁都不能抢。
    final currentSpec = specOf(_current);
    final currentHolding = _enteredAt != null && currentSpec.isOneShot && at.difference(_enteredAt!) < currentSpec.hold;
    if (currentHolding && !currentSpec.interruptible) return null;

    // 同一场景不重复进入（避免「答错两次」把提示动画从头重放）。
    if (target == _current) return null;

    // 规则 2：冷却。
    final last = _lastEntered[target];
    if (last != null && at.difference(last) < targetSpec.cooldown) return null;

    // 规则 3：优先级（只有当前仍在演出时才比）。
    if (currentHolding && targetSpec.priority < currentSpec.priority) return null;

    return _switchTo(target, at);
  }

  MonsterScene _switchTo(MonsterScene scene, DateTime at) {
    _current = scene;
    _enteredAt = at;
    _lastEntered[scene] = at;
    return scene;
  }
}
