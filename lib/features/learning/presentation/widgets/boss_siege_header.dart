import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/core/utils/boss_siege.dart';
import 'package:word_app/core/utils/haptics_gate.dart';
import 'package:word_app/core/utils/sfx.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/effect_palette.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// 复习页的「围城」条带：把剩余到期词画成一列还在门口的小兽，答掉一题少一只。
///
/// 只吃纯值（`done`/`total`/`bossActive`/`shieldSegments`/`stepLabel`，由页面协调层传入）——
/// 本组件族禁止直接读复习会话状态类型（app_structure_test 会扫源码原文，连注释里写出那个类名
/// 都会红，别再犯）。
/// 击退数不另设计数器：`done` 由答题与「标记已掌握」两条路径共同递增，
/// 用它驱动敌列与护盾段天然覆盖两条路径，不会出现「点我熟了的掉不了怪」的穿帮。
class BossSiegeHeader extends StatelessWidget {
  const BossSiegeHeader({
    super.key,
    required this.done,
    required this.total,
    this.bossActive = false,
    this.bossIntroPending = false,
    this.shieldSegments = 0,
    this.shieldCapacity = 0,
    this.stepLabel = '',
    this.onIntroFinished,
  });

  final int done;
  final int total;

  /// 头目是否登场。false 时只画 v1 的喽啰行（既有页面路径保持原样）。
  final bool bossActive;

  /// 当日首次入场动画是否还在播。播完（或 reduce-motion 直接跳过）回调 [onIntroFinished]。
  final bool bossIntroPending;

  /// 已裂开的护盾段数（协调层用 `bossShieldSegments(done)` 算好）。
  final int shieldSegments;

  /// 本局护盾总段数（协调层用 `bossShieldCapacity(total)` 算好）。
  final int shieldCapacity;

  /// 「第 x / N 步 · 还剩 M 步」，由协调层算好；空串则不占位。
  final String stepLabel;

  /// 入场动画结束回调（协调层据此从 pendingIntro 转到 active）。
  final VoidCallback? onIntroFinished;

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
          if (bossActive) ...[
            _BossRow(
              done: done,
              total: total,
              remaining: remaining,
              introPending: bossIntroPending,
              shieldSegments: shieldSegments,
              shieldCapacity: shieldCapacity,
              stepLabel: stepLabel,
              skin: skin,
              onIntroFinished: onIntroFinished,
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              // 敌列：剩余几只画几只（最多 12 只，其余并进 +N，别把答题区挤没）。
              for (var i = 0; i < badge.visible; i++)
                Padding(padding: const EdgeInsets.only(right: 2), child: const _Marauder()),
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

/// 头目行：大一号同源小兽 + 护盾段（辅助） + 步数标签（主进度） + 2px 细进度条。
///
/// 入场动效：当日首次从条带上沿 450ms 滑入 + 淡入；reduce-motion 下直接显示。
/// 护盾每跨 10 只裂一段（封顶 5），裂段时 200ms 抖动 + 变灰 + 一次轻音/轻触。
class _BossRow extends StatefulWidget {
  const _BossRow({
    required this.done,
    required this.total,
    required this.remaining,
    required this.introPending,
    required this.shieldSegments,
    required this.shieldCapacity,
    required this.stepLabel,
    required this.skin,
    required this.onIntroFinished,
  });

  final int done;
  final int total;
  final int remaining;
  final bool introPending;
  final int shieldSegments;
  final int shieldCapacity;
  final String stepLabel;
  final ThemeVars skin;
  final VoidCallback? onIntroFinished;

  @override
  State<_BossRow> createState() => _BossRowState();
}

class _BossRowState extends State<_BossRow> with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final AnimationController _shake;
  int _lastCracked = 0;
  bool _introStarted = false;

  bool get _reduceMotion => WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: MotionDurations.expressive, value: 1);
    final curve = CurvedAnimation(parent: _intro, curve: MotionCurves.accordion);
    _fade = curve;
    _slide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero).animate(curve);
    _shake = AnimationController(vsync: this, duration: MotionDurations.base);
    _lastCracked = bossShieldSegments(widget.done);
    if (widget.introPending) _playIntro();
  }

  @override
  void didUpdateWidget(covariant _BossRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.introPending && !_introStarted) _playIntro();
    final cracked = bossShieldSegments(widget.done);
    if (cracked > _lastCracked) {
      _lastCracked = cracked;
      _crackShield();
    }
  }

  /// 当日首次入场：450ms 滑入 + 淡入；reduce-motion 直接显示并立即交回协调层。
  void _playIntro() {
    _introStarted = true;
    if (_reduceMotion) {
      _intro.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _finishIntro());
      return;
    }
    _intro.value = 0;
    _intro.forward().whenComplete(_finishIntro);
  }

  void _finishIntro() {
    if (!mounted) return;
    widget.onIntroFinished?.call();
  }

  /// 护盾裂一段：200ms 抖动 + 一次轻音/轻触；reduce-motion 只变灰，不抖不发声。
  void _crackShield() {
    if (_reduceMotion) return;
    _shake.forward(from: 0);
    SfxPlayer.fire(Sfx.coinTick);
    HapticsGate.play(HapticCue.light);
  }

  @override
  void dispose() {
    _intro.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final progress = widget.total == 0 ? 0.0 : (widget.done / widget.total).clamp(0.0, 1.0);
    return FadeTransition(
      key: const ValueKey('boss-intro-fade'),
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 头目与喽啰的视觉区分：雾岭紫 + 飞翼形态（v2 收尾）。
                // 只是「来自雾岭的大个子」，不表达更强/更坏的评价。
                const MonsterIcon(size: 44, bodyColor: MonsterPalette.bossMist, evoStage: 2),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        bossNarrative(remaining: widget.remaining),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MwTypography.micro.copyWith(fontWeight: FontWeight.w600, color: skin.text2),
                      ),
                      if (widget.shieldCapacity > 0) ...[const SizedBox(height: 4), _buildShieldRow(skin)],
                    ],
                  ),
                ),
                if (widget.stepLabel.isNotEmpty)
                  Text(widget.stepLabel, style: MwTypography.micro.copyWith(color: skin.text3)),
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
        ),
      ),
    );
  }

  /// 护盾段：裂开的变灰，未裂的保持主题强调色；裂段瞬间整行轻抖一下。
  Widget _buildShieldRow(ThemeVars skin) {
    final capacity = widget.shieldCapacity;
    final cracked = widget.shieldSegments.clamp(0, capacity);
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final phase = _shake.value;
        final dx = _reduceMotion ? 0.0 : math.sin(phase * math.pi * 4) * 1.5;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < capacity; i++)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: AnimatedContainer(
                key: ValueKey('boss-shield-$i'),
                duration: _reduceMotion ? Duration.zero : MotionDurations.base,
                width: 12,
                height: 3,
                decoration: BoxDecoration(
                  color: i < cracked ? skin.text3.withValues(alpha: AppAlphas.o35) : skin.accent,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 一只捣蛋兽：奶泡形态的缩小版（它们就是「忘掉的词」变的，不是外来的怪物）。
class _Marauder extends StatelessWidget {
  const _Marauder();

  @override
  Widget build(BuildContext context) => const MonsterIcon(size: 16, evoStage: 0);
}
