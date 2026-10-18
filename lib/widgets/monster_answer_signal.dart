// 把「答对/答错」这个事实报给怪兽演出层（共享组件层）。
//
// 为什么单独一个函数：learn_page 与 review_page 都要报，而 `learn_page.dart`
// 已经贴着 900 行上限（`code_style_guard_test` 硬约束），内联一份就等于两处重复
// 加两处行数。抽出来后两边各一行。
//
// 可空读取：最小装配的 widget 测试没有 companion scope，报事实这件事直接跳过
// —— 这是本仓踩过 3 次的坑，不要改成非空读取。
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/utils/monster_event.dart';
import 'package:word_app/features/companion/application/monster_companion_port.dart';

/// 上报一次作答结果。连续答错的升级（→ 三词小组）由 companion 自己数，
/// 调用方只需报事实。
void announceMonsterAnswer(BuildContext context, {required bool correct}) {
  context.read<MonsterCompanionController?>()?.dispatch(
    correct ? MonsterEvent.answerCorrect : MonsterEvent.answerWrong,
  );
}
