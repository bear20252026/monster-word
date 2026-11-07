// 由 Claude 团队生成 | Monster Word App
// 学习完成结算页：发币结算 / 目标庆祝 / 四项统计 / 战报分享 / 复习错题入口。
// 自 learn_page.dart 拆出（code_style_guard：单文件 ≤900 行 / build() ≤120 行）。
import 'dart:async';

import 'package:word_app/core/utils/monster_bond_prefs.dart';
import 'package:word_app/core/utils/sfx.dart';
import 'package:word_app/widgets/common/mw_feedback.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/checkin/application/streak_milestones.dart';
import 'package:word_app/features/learning/application/completion_cards.dart';
import 'package:word_app/features/learning/application/learning_reward_service.dart';
import 'package:word_app/features/learning/presentation/share_image_service.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
// M3：XP / 等级（只 import 对方的 application 层，架构守卫 R4 允许）。
import 'package:word_app/features/progress/application/xp_store.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
// 埋点端口（跨 feature 只 import 对方的 application 层，架构守卫 R4 允许）。
import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/monster_feed_celebration.dart';
import 'package:word_app/widgets/bond_level_up_overlay.dart';
import 'package:word_app/widgets/monster_icon.dart';

class LearnCompletionScreen extends StatefulWidget {
  final SkinSystem skin;
  final int errorCount;
  final int totalAnswered;
  final int? durationSeconds;
  final double? accuracy;
  final VoidCallback? onReviewErrors;

  /// 「再来一组」：开一局新学习。返回是否真的装载了新词（false → 页面保持）。
  final Future<bool> Function()? onPlayAgain;

  /// 本次会话最佳连击（连击条口径）。
  final int bestCombo;
  const LearnCompletionScreen({
    required this.skin,
    this.errorCount = 0,
    this.totalAnswered = 0,
    this.durationSeconds,
    this.accuracy,
    this.onReviewErrors,
    this.onPlayAgain,
    this.goalAchieved = false,
    this.todayLearned = 0,
    this.dailyGoal = 0,
    this.bestCombo = 0,
    super.key,
  });

  /// 今日目标达成（显示庆祝横幅）
  final bool goalAchieved;
  final int todayLearned;
  final int dailyGoal;

  @override
  State<LearnCompletionScreen> createState() => _LearnCompletionScreenState();
}

class _LearnCompletionScreenState extends State<LearnCompletionScreen> {
  int? _grantedCoins;
  bool _sharing = false;

  /// M3/D4：本局 XP 与升级信息（只在本页展示，不进商店）。
  int? _grantedXp;
  int? _xpToNextLevel;
  int? _levelUpLevel;

  /// 「再来一组」装载中：禁用按钮，避免连点叠出两局。
  bool _startingAgain = false;

  /// 怪兽进化阶段（签到天数换算；喂币庆祝用它——进化不该只在探头页可见）。
  int _evoStage = 0;

  /// 连胜一行（无连胜/读取失败为 null → 不显示）。
  String? _streakLine;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStreakLine());
    // 会话结算（发币）只在完成页首次展示时执行一次；失败不打断——奖励不应阻塞完成页，异常已上报。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 复习错题后再次完成会重挂载本页；每会话只结算一次
      final sessionState = context.read<LearningSessionState>();
      // M3：XP 与币分开结算（先发经验，币的闸不影响经验重试）。XP 幂等靠本局
      // sessionId 事件键，重复挂载/重复结算都不会重复加经验。
      final xpStore = context.read<XpStore?>();
      if (xpStore != null) unawaited(_grantXp(xpStore, sessionState.sessionId));
      if (sessionState.sessionRewardSettled) return;
      sessionState.markSessionRewardSettled();
      // 埋点端口在 await 前取好：await 之后 context 可能已失效。
      // **可空读取**：最小装配的单测没有 telemetry scope，不该因此抛 ProviderNotFound。
      // 会话数/答题数由 LearningSessionState 在队列走完时上报（那里有唯一的计数口径），
      // 这里只补「本次结算实际发出的尖叫币」。
      final usageStats = context.read<UsageStatsRecorder?>();
      final store = context.read<ScareCoinStore>();
      final service = LearningRewardService(store);
      // 形态异步补齐（喂币庆祝的怪兽随真实进化阶段换装；失败降级奶泡态）。
      unawaited(
        store
            .checkinDates()
            .then((dates) {
              if (mounted) setState(() => _evoStage = MonsterIcon.stageFor(dates.length));
            })
            .catchError((Object e, StackTrace s) {
              reportSwallowedError('完成页形态读取失败', e, s);
            }),
      );
      try {
        // 2026-10-17 审计 P2：会话完成时已把「待发币」登记进 SP（不需要账本），
        // 这里只负责把它结算掉并演出来。若应用在完成页挂载前被杀，
        // 下次启动的 drain 会补发，不会静默丢奖。
        final result = await service.settlePendingSessions();
        // 使用统计：本次会话实际发出的尖叫币（0 时实现方空转，无需判断）。
        if (usageStats != null) unawaited(usageStats.recordCoinsEarned(result.totalGranted));
        if (!mounted || result.totalGranted <= 0) return;
        // W4.5 宠物化：喂到它了（发币成功 = 喂食成功）→ 羁绊 +1/日。
        // 失败要上报（对照抚摸侧口径）：_record 内 SP 写抛错否则进 unhandled。
        // 2026-10-17 审计 P2：recordFeed 现在直接回传记账前后的点数，
        // 不再需要额外两次 points() 读 —— 原先这里是「读/写/再读」三次独立 SP 往返。
        unawaited(
          MonsterBondPrefs.recordFeed()
              .then<void>((feed) async {
                // 喂食跨羁绊阈值：等吞币庆祝先演完（延迟 2.2s）再升羁绊仪式。
                final beforeLevel = BondLevel.levelOf(feed.pointsBefore);
                final afterLevel = BondLevel.levelOf(feed.pointsAfter);
                if (afterLevel.min > beforeLevel.min) {
                  await Future<void>.delayed(const Duration(milliseconds: 2200));
                  if (!mounted) return;
                  final next = BondLevel.nextMin(feed.pointsAfter);
                  BondLevelUpOverlay.show(
                    context,
                    levelName: afterLevel.name,
                    pointsToNext: next == null ? null : next - feed.pointsAfter,
                  );
                }
              })
              .catchError((Object e, StackTrace s) {
                reportSwallowedError('喂食羁绊记账失败', e, s);
              }),
        );
        SfxPlayer.fire(Sfx.milestone);
        setState(() => _grantedCoins = result.totalGranted);
      } catch (e, s) {
        // 奖励结算失败不打断完成页（异常已上报）；下次会话仍有机会获得
        reportSwallowedError('会话结算发币失败', e, s);
      }
    });
  }

  /// M3：答对 1 词 +2 XP、完成一局 +10（复习同计）；升级只庆祝一次。
  ///
  /// [sessionId] 是本局幂等键：同一局重复结算不会重复加经验。
  Future<void> _grantXp(XpStore store, String sessionId) async {
    try {
      final correct = (widget.totalAnswered - widget.errorCount).clamp(0, widget.totalAnswered);
      final result = await store.grantSession(
        eventKey: 'xp:learn:$sessionId',
        answered: widget.totalAnswered,
        correct: correct,
        completed: widget.totalAnswered > 0,
      );
      if (!mounted || result.awarded <= 0) return;
      setState(() {
        _grantedXp = result.awarded;
        _xpToNextLevel = result.snapshot.xpToNextLevel;
      });
      final newLevel = result.newLevel;
      if (newLevel == null) return;
      if (!await store.claimLevelUpCelebration(newLevel)) return;
      if (!mounted) return;
      setState(() => _levelUpLevel = newLevel);
      SfxPlayer.fire(Sfx.milestone);
    } catch (e, s) {
      reportSwallowedError('会话 XP 结算失败', e, s);
    }
  }

  /// 连胜一行：读连签与今日签到状态；失败降级为不显示（C 级豁免）。
  Future<void> _loadStreakLine() async {
    try {
      final store = context.read<ScareCoinStore?>();
      if (store == null) return;
      final streak = await store.streak();
      final last = await store.lastCheckInDate();
      if (!mounted) return;
      final checkedToday = last.isNotEmpty && store.isSameDay(last, DateTime.now());
      setState(() => _streakLine = completionStreakLine(streakDays: streak, checkedToday: checkedToday));
    } catch (e, s) {
      reportSwallowedError('结算页连胜读取失败', e, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(AppSpacing.xxl), child: _buildContent(widget.skin.colors)),
      ),
    );
  }

  /// 结算主体：主视觉 → 标题 → 横幅 → 三卡 → 小字 → 次入口 → 主 CTA。
  ///
  /// 主按钮是「再来一组」（直接开新局），「返回首页」降为文字链——
  /// 完成一局不该只能退出，闭环要能继续。
  Widget _buildContent(dynamic colors) {
    final cards = buildCompletionCards(
      totalAnswered: widget.totalAnswered,
      errorCount: widget.errorCount,
      accuracy: widget.accuracy,
      durationSeconds: widget.durationSeconds,
      bestCombo: widget.bestCombo,
    );
    final onReviewErrors = widget.onReviewErrors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 结算成功（totalGranted > 0）→ 怪兽吃币庆祝主视觉；0/失败态保留图标现状。
        if (_grantedCoins != null && _grantedCoins! > 0)
          MonsterFeedCelebration(coinCount: _grantedCoins!, evoStage: _evoStage)
        else
          Icon(Icons.celebration, size: 80, color: colors.accent),
        const SizedBox(height: 24),
        Text(
          '今日学习完成！',
          style: MwTypography.displaySm.copyWith(fontWeight: FontWeight.bold, color: colors.text1),
        ),
        const SizedBox(height: 12),
        // 尖叫币奖励横幅（本次会话结算所得）
        if (_grantedCoins != null && _grantedCoins! > 0) ...[_buildCoinBanner(colors), const SizedBox(height: 12)],
        // M3/D4：经验横幅（+N 经验 / 升级还需 M / 升级到 Lv.N）
        if (_grantedXp != null) ...[_buildXpBanner(colors), const SizedBox(height: 12)],
        // 今日目标达成庆祝横幅
        if (widget.goalAchieved) ...[_buildGoalBanner(colors), const SizedBox(height: 12)],
        Text(
          onReviewErrors != null && widget.errorCount > 0
              ? '本次学习了 ${widget.totalAnswered} 个单词，错了 ${widget.errorCount} 个'
              : '你已经完成了今天的所有单词，太棒了！',
          style: MwTypography.bodyMd.copyWith(color: colors.text2),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        // 三卡：本次词数 / 正确率（≥90% 带称号）/ 用时；答错与连击降为一行小字。
        _buildCards(colors, cards),
        if (cards.note != null) ...[
          const SizedBox(height: 10),
          Text(cards.note!, style: MwTypography.micro.copyWith(color: colors.text3)),
        ],
        // 连胜一行：把连胜当作本局结果的一部分（无连胜不占位）。
        if (_streakLine != null) ...[
          const SizedBox(height: 8),
          Text(_streakLine!, style: MwTypography.micro.copyWith(color: colors.text3)),
        ],
        const SizedBox(height: 20),
        // 战报分享：今日战绩海报，自带传播。
        OutlinedButton.icon(
          onPressed: _sharing ? null : _shareReport,
          icon: _sharing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.ios_share_rounded, size: 18),
          label: Text(_sharing ? '正在生成海报…' : '分享今日战报'),
        ),
        if (onReviewErrors != null && widget.errorCount > 0) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onReviewErrors,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('复习错题'),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.onGlassAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            // 装载中禁用，避免连点叠出两局
            onPressed: widget.onPlayAgain == null || _startingAgain ? null : _startAnotherGroup,
            child: Text(
              _startingAgain ? '正在准备…' : '再来一组',
              style: const TextStyle(fontSize: AppFontSizes.bodyMd, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => NavUtils.goHome(context),
          style: TextButton.styleFrom(foregroundColor: colors.text3),
          child: const Text('返回首页', style: TextStyle(fontSize: AppFontSizes.caption)),
        ),
      ],
    );
  }

  /// 今日目标达成横幅。
  Widget _buildGoalBanner(dynamic colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: AppAlphas.o12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.accent.withValues(alpha: AppAlphas.o40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, size: 16, color: colors.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '今日目标达成！已学 ${widget.todayLearned} / 目标 ${widget.dailyGoal}',
              style: MwTypography.bodySm.copyWith(fontWeight: FontWeight.w700, color: colors.accent),
            ),
          ),
        ],
      ),
    );
  }

  /// 三卡横排（等高）。
  Widget _buildCards(dynamic colors, CompletionCards data) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < data.cards.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _CompletionCardView(card: data.cards[i], colors: colors),
            ),
          ],
        ],
      ),
    );
  }

  /// 「再来一组」：交给会话开新局；装载失败则解锁并提示，结算页数据不变。
  Future<void> _startAnotherGroup() async {
    final onPlayAgain = widget.onPlayAgain;
    if (onPlayAgain == null || _startingAgain) return;
    setState(() => _startingAgain = true);
    final started = await onPlayAgain();
    if (!mounted || started) return; // 新局已接管页面（本页被替换）
    setState(() => _startingAgain = false);
    showMwSnackBar(context, const SnackBar(content: Text('暂时没有可以继续的词')));
  }

  /// 分享今日战报（无账本语境连签记 0，不抛错）。
  Future<void> _shareReport() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final store = context.read<ScareCoinStore?>();
      int streakDays = 0;
      try {
        streakDays = await (store?.streak() ?? Future.value(0));
      } catch (_) {
        // C 级豁免：连签天数读不到仅影响分享文案展示为 0 天
      }
      if (!mounted) return;
      final correct = (widget.totalAnswered - widget.errorCount).clamp(0, widget.totalAnswered);
      final accuracyText = widget.accuracy == null ? '--' : '${(widget.accuracy! * 100).round()}%';
      await ShareImageService.generateAndShareDailyReport(
        correct: correct,
        total: widget.totalAnswered,
        accuracyText: accuracyText,
        bestCombo: widget.bestCombo,
        streakDays: streakDays,
      );
    } catch (_) {
      if (mounted) {
        showMwSnackBar(context, const SnackBar(content: Text('分享失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// 经验横幅（M3/D4）：+N 经验 · 升级还需 M；升级时文案切成「升级到 Lv.N」。
  Widget _buildXpBanner(dynamic colors) {
    final levelUp = _levelUpLevel;
    final toNext = _xpToNextLevel;
    final text = levelUp != null ? '升级到 Lv.$levelUp！' : '经验 +$_grantedXp · 升级还需 $toNext';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: AppAlphas.o12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.accent.withValues(alpha: AppAlphas.o40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            levelUp != null ? Icons.arrow_upward_rounded : Icons.auto_awesome_rounded,
            size: 16,
            color: colors.accent,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: MwTypography.bodySm.copyWith(fontWeight: FontWeight.w700, color: colors.accent),
          ),
        ],
      ),
    );
  }

  /// 尖叫币奖励横幅（本次会话结算所得）
  Widget _buildCoinBanner(dynamic colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: AppAlphas.o12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.accent.withValues(alpha: AppAlphas.o40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MonsterAvatar(size: 20),
          const SizedBox(width: 6),
          Text(
            '尖叫币 +$_grantedCoins',
            style: MwTypography.bodySm.copyWith(fontWeight: FontWeight.w700, color: colors.accent),
          ),
        ],
      ),
    );
  }
}

/// 单张结算卡：大数值 + 可选称号 + 标签，底色按语义色调淡染。
class _CompletionCardView extends StatelessWidget {
  const _CompletionCardView({required this.card, required this.colors});

  final CompletionCard card;
  final dynamic colors;

  @override
  Widget build(BuildContext context) {
    final Color tint = switch (card.tone) {
      CompletionCardTone.primary => colors.accent as Color,
      CompletionCardTone.achievement => colors.success as Color,
      CompletionCardTone.neutral => colors.text1 as Color,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: AppAlphas.o10),
        borderRadius: BorderRadius.circular(context.design.radius.control),
        border: Border.all(color: tint.withValues(alpha: AppAlphas.o20)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MwTypography.titleLg.copyWith(fontWeight: FontWeight.bold, color: tint),
          ),
          if (card.title != null) ...[
            const SizedBox(height: 2),
            Text(
              card.title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MwTypography.micro.copyWith(fontWeight: FontWeight.w700, color: tint),
            ),
          ],
          const SizedBox(height: 4),
          Text(card.label, style: MwTypography.micro.copyWith(color: colors.text3)),
        ],
      ),
    );
  }
}
