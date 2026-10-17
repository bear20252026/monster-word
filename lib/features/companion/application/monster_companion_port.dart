// companion 域的对外端口（application 层）。
//
// 为什么需要这一层：架构守卫（R4 / R-widgets）只允许「跨 feature」与
// 「widgets/ 共享组件层」消费对方 feature 的 **application** 层。首页要显示怪兽，
// 但它既不能 import `companion/presentation`，`widgets/` 也不能。
// ⇒ 对外只暴露这个**只读 + 少量写**的窄接口，具体实现（ChangeNotifier）留在
// presentation 层，装配时用 ChangeNotifierProxyProvider 桥过去。
//
// 端口刻意保持「哑」：只有场景与一句话，不暴露场景图、事件表、主动性规则。
// 消费方不需要知道 VPet 那套调度是怎么实现的。
import 'package:flutter/foundation.dart';

import 'package:word_app/core/utils/monster_event.dart';
import 'package:word_app/core/utils/monster_initiative.dart';
import 'package:word_app/core/utils/monster_scene.dart';

/// 只读面：渲染怪兽需要的一切。
abstract class MonsterCompanionReader implements Listenable {
  /// 当前场景（决定表情/动作）。
  MonsterScene get scene;

  /// 此刻想说的话；null = 不说话（没话说 / 无文案槽 / 每日预算用尽）。
  String? get line;
}

/// 可写面：数据层把事实推给演出层。
abstract class MonsterCompanionController implements MonsterCompanionReader {
  /// 用最新事实刷新「它想说什么」。幂等：同类建议不换台词、不重复通知。
  void refreshInitiative(MonsterInitiativeInput input);

  /// 推一个事实事件（开始学习/答错/完成…）。返回是否发生场景切换。
  bool dispatch(MonsterEvent event, {DateTime? at});

  /// 定时推进：一次性演出到点回落。返回是否切换。
  bool tick({DateTime? at});
}
