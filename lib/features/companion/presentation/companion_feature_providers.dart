// companion 功能域的装配入口。
//
// ⚠️ 位置很关键：本 scope 必须挂在 **ScareCoin（[9]）之后**，因为怪兽的主动性
// 需要读账本（「签到断了几天」）与 learning 的到期数；Provider 只能向下查找。
// 这与 P2 那次踩过的坑同源（learning 在 scare_coin 外层 ⇒ 状态层拿不到账本），
// 所以这里刻意放在最内层 [14]，不做「省一层」的优化。
//
// 对外暴露两个面：
// - `MonsterCompanionState`（具体 ChangeNotifier）：feature 内部与测试用；
// - `MonsterCompanionController`（application 端口）：共享组件层与其它 feature 用。
//   架构守卫只允许它们消费 application 层，所以必须桥一道。
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/companion/application/monster_companion_port.dart';
import 'package:word_app/features/companion/presentation/monster_companion_state.dart';

Widget buildCompanionFeatureScope({required Widget child}) {
  return ChangeNotifierProvider<MonsterCompanionState>(
    create: (_) => MonsterCompanionState(),
    // 用 ListenableProvider（不是 ChangeNotifierProvider）：端口是抽象接口，
    // 不满足 ChangeNotifierProvider 的 `T extends ChangeNotifier` 约束，
    // 但它实现的 Listenable 足够让 widgets/ 里的舞台收到更新。
    // 同一实例两副面孔：feature 内部用具体类，外部只认 application 端口。
    child: ListenableProvider<MonsterCompanionController>(
      create: (context) => context.read<MonsterCompanionState>(),
      child: child,
    ),
  );
}
