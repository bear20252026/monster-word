// 怪兽首屏舞台（共享组件层）。
//
// 为什么放在 widgets/ 而不是 companion/presentation：
// 架构守卫（R4）禁止 feature 之间互相 import presentation 层，R-widgets 又要求
// 共享组件层只能消费 feature 的 **application** 端口 ⇒ 首页能用的「怪兽」
// 必须落在这里，并且只经 `MonsterCompanionController` 端口与 companion 通信。
//
// 可测性红线（本仓踩过 3 次）：widget 测试是最小装配，**读 Provider 一律可空读取**。
// provider 6.x 的 `of<T?>` 按 `_InheritedProviderScope<T?>` 查，查不到且
// `null is T` 时返回 null 而非抛 ⇒ 没有 companion 装配时这里退化成静态待机怪兽。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/companion/application/monster_companion_port.dart';
import 'package:word_app/core/utils/monster_initiative.dart';
import 'package:word_app/core/utils/monster_scene.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// 场景 → 表情参数（纯函数，便于单测锚定）。
({double mouthOpen, double cheekPuff, bool sad, double bellyScale}) sceneExpression(MonsterScene scene) =>
    switch (scene) {
      MonsterScene.idle => (mouthOpen: 0, cheekPuff: 0, sad: false, bellyScale: 1),
      // 欢迎：张嘴笑 + 鼓脸，最开心的一档。
      MonsterScene.greeting => (mouthOpen: 0.6, cheekPuff: 0.5, sad: false, bellyScale: 1.02),
      // 准备：深吸一口气（肚子微涨），不笑 —— 建立「要开始了」的仪式感。
      MonsterScene.preparing => (mouthOpen: 0.1, cheekPuff: 0.15, sad: false, bellyScale: 1.06),
      // 指提示：专注，不卖萌（此刻用户需要的是帮助，不是可爱）。
      MonsterScene.hinting => (mouthOpen: 0.3, cheekPuff: 0.2, sad: false, bellyScale: 1),
      // 连续困难：陪着难过，不是评判。
      MonsterScene.regrouping => (mouthOpen: 0.15, cheekPuff: 0.3, sad: true, bellyScale: 1),
      // 搬词卡：用力（肚子鼓）。
      MonsterScene.carrying => (mouthOpen: 0.2, cheekPuff: 0.25, sad: false, bellyScale: 1.05),
      // 总结：说话状。
      MonsterScene.summarizing => (mouthOpen: 0.5, cheekPuff: 0.3, sad: false, bellyScale: 1),
      // 庆祝：最夸张一档。
      MonsterScene.celebrating => (mouthOpen: 0.9, cheekPuff: 0.8, sad: false, bellyScale: 1.08),
    };

/// 首页首屏的怪兽主位：气泡（可选）+ 怪兽本体。
class MonsterStage extends StatelessWidget {
  const MonsterStage({super.key, this.size = 132, this.onTap});

  /// 怪兽直径。
  final double size;

  /// 点击回调（宿主可用来冒一句日常台词）。null = 不可点。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // 可空读取：见文件头。没有装配时按待机演。
    final companion = context.watch<MonsterCompanionController?>();
    final scene = companion?.scene ?? MonsterScene.idle;
    final line = companion?.line;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
    final expr = sceneExpression(scene);

    final monster = AnimatedSwitcher(
      duration: duration,
      child: MonsterIcon(
        // key 让场景变化触发淡入淡出，而不是「表情瞬间跳一下」。
        key: ValueKey(scene),
        size: size,
        mouthOpen: expr.mouthOpen,
        cheekPuff: expr.cheekPuff,
        sad: expr.sad,
        bellyScale: expr.bellyScale,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 气泡只在有话时说：没话说时不留空壳，避免「它张嘴却不出声」的怪感。
        AnimatedSize(
          duration: duration,
          alignment: Alignment.bottomCenter,
          child: line == null
              ? const SizedBox(width: double.infinity)
              : _SpeechBubble(text: line, maxWidth: size * 2.2),
        ),
        if (line != null) SizedBox(height: 8 * (size / 132)),
        Semantics(
          label: '小怪兽',
          button: onTap != null,
          child: onTap == null ? monster : GestureDetector(onTap: onTap, child: monster),
        ),
      ],
    );
  }
}

/// 把「事实」喂给怪兽：到期数 + 今天是否已学。
///
/// 只喂**同步可得**的两项。`daysSinceLastCheckin` / `daysSinceLastVisit` 要异步读
/// SP，留给后续接入；缺省 0 时规则自然不触发（不会误催）。
class MonsterStageWithFacts extends StatelessWidget {
  const MonsterStageWithFacts({super.key, required this.dueCount, required this.studiedToday, required this.builder});

  final int dueCount;
  final bool studiedToday;

  /// 由宿主决定怎么画（尺寸/点击行为各不相同），事实由本 widget 负责喂。
  final Widget Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<MonsterCompanionController?>();
    // 喂事实不能放在 build 里直接改状态（会在 build 期间 notifyListeners），
    // 用 post-frame 推到下一帧。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller?.refreshInitiative(MonsterInitiativeInput(dueCount: dueCount, studiedToday: studiedToday));
    });
    return builder(context);
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, required this.maxWidth});

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.cardBg,
          // 用设计 token（R6/字体与圆角卫生守卫按字面量计库存，新增字面量会让 CI 红）。
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: colors.divider),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: AppFontSizes.caption, height: 1.35, color: colors.text1),
        ),
      ),
    );
  }
}
