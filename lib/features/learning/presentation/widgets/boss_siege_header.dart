import 'package:flutter/material.dart';

import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/core/utils/boss_siege.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// 复习页的「围城」条带：把剩余到期词画成一列还在门口的小兽，答掉一题少一只。
///
/// 只吃纯值（`done`/`total`/`bossActive`/`stepLabel`，由页面协调层传入）——本组件族禁止直接读复习会话状态
/// 类型（app_structure_test 会扫源码原文，连注释里写出那个类名都会红，别再犯）。
/// 击退数不另设计数器：`done` 由答题与「标记已掌握」两条路径共同递增，
/// 用它驱动敌列天然覆盖两条路径，不会出现「点我熟了的掉不了怪」的穿帮。
class BossSiegeHeader extends StatelessWidget {
  const BossSiegeHeader({
    super.key,
    required this.done,
    required this.total,
    this.bossActive = false,
    this.stepLabel = '',
  });

  final int done;
  final int total;

  /// 头目是否登场。false 时只画 v1 的喽啰行（既有页面路径保持原样）。
  final bool bossActive;

  /// 「第 x / N 步 · 还剩 M 步」，由协调层算好；空串则不占位。
  final String stepLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final resp = context.responsive;
    final remaining = (total - done).clamp(0, total);
    final tier = siegeTierFor(remaining);
    final badge = marauderBadgeCounts(remaining);
    if (total <= 0) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(resp.horizontalPadding * 0.5, 0, resp.horizontalPadding * 0.5, AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头目行（M0 最小集）：静态呈现，不做入场动画、不分护盾段。
          if (bossActive) ...[
            _BossRow(done: done, total: total, remaining: remaining, stepLabel: stepLabel, skin: skin),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              // 敌列：剩余几只画几只（最多 12 只，其余并进 +N，别把答题区挤没）。
              for (var i = 0; i < badge.visible; i++) Padding(padding: const EdgeInsets.only(right: 2), child: _Marauder()),
              if (badge.overflow > 0)
                Text(
                  '+${badge.overflow}',
                  style: MwTypography.micro.copyWith(fontWeight: FontWeight.w700, color: skin.text3),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  siegeNarrative(tier, remaining),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MwTypography.micro.copyWith(color: skin.text3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 头目行：大一号同源小兽 + 一句事实叙述 + 步数标签 + 2px 细进度条。
///
/// 进度以「还剩几步」为主（参考 word-atlas 的步数口径），不复用顶部 6px 总进度条，
/// 让用户在答题区上方一眼就能看到本局边界。
class _BossRow extends StatelessWidget {
  const _BossRow({
    required this.done,
    required this.total,
    required this.remaining,
    required this.stepLabel,
    required this.skin,
  });

  final int done;
  final int total;
  final int remaining;
  final String stepLabel;
  final ThemeVars skin;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const MonsterIcon(size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                bossNarrative(remaining: remaining),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MwTypography.micro.copyWith(fontWeight: FontWeight.w600, color: skin.text2),
              ),
            ),
            if (stepLabel.isNotEmpty)
              Text(stepLabel, style: MwTypography.micro.copyWith(color: skin.text3)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            backgroundColor: skin.onGlassText2.withValues(alpha: AppAlphas.o18),
            valueColor: AlwaysStoppedAnimation(skin.accent),
          ),
        ),
      ],
    );
  }
}

/// 一只捣蛋兽：奶泡形态的缩小版（它们就是「忘掉的词」变的，不是外来的怪物）。
class _Marauder extends StatelessWidget {
  const _Marauder();

  @override
  Widget build(BuildContext context) => const MonsterIcon(size: 16, evoStage: 0);
}
