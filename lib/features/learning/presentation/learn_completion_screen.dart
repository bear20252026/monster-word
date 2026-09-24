// 由 Claude 团队生成 | Monster Word App
// 学习完成结算页：发币结算 / 目标庆祝 / 四项统计 / 战报分享 / 复习错题入口。
// 自 learn_page.dart 拆出（code_style_guard：单文件 ≤900 行 / build() ≤120 行）。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/features/learning/application/learning_reward_service.dart';
import 'package:word_app/features/learning/presentation/share_image_service.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/monster_icon.dart';

class LearnCompletionScreen extends StatefulWidget {
  final SkinSystem skin;
  final int errorCount;
  final int totalAnswered;
  final int? durationSeconds;
  final double? accuracy;
  final VoidCallback? onReviewErrors;

  /// 本次会话最佳连击（连击条口径）。
  final int bestCombo;
  const LearnCompletionScreen({
    required this.skin,
    this.errorCount = 0,
    this.totalAnswered = 0,
    this.durationSeconds,
    this.accuracy,
    this.onReviewErrors,
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

  @override
  void initState() {
    super.initState();
    // 会话结算（发币）只在完成页首次展示时执行一次；失败静默——奖励不应阻塞完成页。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 复习错题后再次完成会重挂载本页；每会话只结算一次
      final sessionState = context.read<LearningSessionState>();
      if (sessionState.sessionRewardSettled) return;
      sessionState.markSessionRewardSettled();
      final store = context.read<ScareCoinStore>();
      final service = LearningRewardService(store);
      try {
        final result = await service.settleSession(
          wordsLearned: widget.totalAnswered,
          dailyGoalAchieved: widget.goalAchieved,
        );
        if (!mounted || result.totalGranted <= 0) return;
        setState(() => _grantedCoins = result.totalGranted);
      } catch (_) {
        // 奖励结算失败不打断完成页；下次会话仍有机会获得
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.skin.colors;
    final goalAchieved = widget.goalAchieved;
    final todayLearned = widget.todayLearned;
    final dailyGoal = widget.dailyGoal;
    final errorCount = widget.errorCount;
    final totalAnswered = widget.totalAnswered;
    final durationSeconds = widget.durationSeconds;
    final accuracy = widget.accuracy;
    final onReviewErrors = widget.onReviewErrors;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.celebration, size: 80, color: colors.accent),
              const SizedBox(height: 24),
              Text(
                '今日学习完成！',
                style: MwTypography.displaySm.copyWith(fontWeight: FontWeight.bold, color: colors.text1),
              ),
              const SizedBox(height: 12),
              // 尖叫币奖励横幅（本次会话结算所得）
              if (_grantedCoins != null && _grantedCoins! > 0) ...[
                _buildCoinBanner(colors),
                const SizedBox(height: 12),
              ],
              // 今日目标达成庆祝横幅
              if (goalAchieved) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_rounded, size: 16, color: colors.accent),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '今日目标达成！已学 $todayLearned / 目标 $dailyGoal',
                          style: MwTypography.bodySm.copyWith(fontWeight: FontWeight.w700, color: colors.accent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                onReviewErrors != null && errorCount > 0
                    ? '本次学习了 $totalAnswered 个单词，错了 $errorCount 个'
                    : '你已经完成了今天的所有单词，太棒了！',
                style: MwTypography.bodyMd.copyWith(color: colors.text2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildStatsCard(colors, accuracy: accuracy, durationSeconds: durationSeconds, errorCount: errorCount),
              const SizedBox(height: 16),
              // 战报分享：今日战绩海报，自带传播。
              OutlinedButton.icon(
                onPressed: _sharing ? null : _shareReport,
                icon: _sharing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(_sharing ? '正在生成海报…' : '分享今日战报'),
              ),
              if (onReviewErrors != null && errorCount > 0) ...[
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
                  onPressed: () => NavUtils.goHome(context),
                  child: const Text(
                    '返回首页',
                    style: TextStyle(fontSize: AppFontSizes.bodyMd, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      } catch (_) {}
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分享失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// 四项统计卡（答对率/用时/答错/最高连击）。
  Widget _buildStatsCard(
    dynamic colors, {
    required double? accuracy,
    required int? durationSeconds,
    required int errorCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.control),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: '答对率', value: accuracy == null ? '--' : '${(accuracy * 100).round()}%', colors: colors),
          _StatItem(
            label: '用时',
            value: durationSeconds == null ? '--' : _formatDuration(durationSeconds),
            colors: colors,
          ),
          _StatItem(label: '答错', value: '$errorCount', colors: colors),
          _StatItem(label: '最高连击', value: widget.bestCombo > 0 ? '×${widget.bestCombo}' : '--', colors: colors),
        ],
      ),
    );
  }

  /// 尖叫币奖励横幅（本次会话结算所得）
  Widget _buildCoinBanner(dynamic colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
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

  static String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds秒';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) {
      return remainingSeconds > 0 ? '$minutes分$remainingSeconds秒' : '$minutes分钟';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes > 0 ? '$hours时$remainingMinutes分' : '$hours小时';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final dynamic colors;
  const _StatItem({required this.label, required this.value, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: MwTypography.titleLg.copyWith(fontWeight: FontWeight.bold, color: colors.text1),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: MwTypography.micro.copyWith(fontWeight: FontWeight.w400, color: colors.text3),
        ),
      ],
    );
  }
}
