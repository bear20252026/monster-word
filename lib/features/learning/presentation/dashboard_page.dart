// 由 Claude 团队生成 | Monster Word App

// 仪表盘页 — 编辑式记忆图谱版面。
// v2.7.61 重构：以「总词汇量」大数字为视觉锚点，FSRS 记忆状态收敛为
// 单条堆叠比例条 + 图例（一眼读出记忆构成）；正学习词书卡保留进度条。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/features/learning/presentation/share_image_service.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/features/learning/presentation/learning_statistics_state.dart';
import 'package:word_app/widgets/mw_section_header.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const routeName = '/dashboard';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LearningStatisticsState>();
    final book = state.currentBook;
    final learned = state.learnedCount;
    final skin = context.skin.colors;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.responsive.contentWidth),
            child: Column(
              children: [
                _buildTopNav(context, skin),
                Container(height: 1, color: skin.divider),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(context.responsive.pageMargin),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        MwSectionHeader(title: '正在学习'),
                        const SizedBox(height: 14),
                        _buildCurrentBookCard(context, book, learned, skin),
                        const SizedBox(height: 32),
                        MwSectionHeader(title: '记忆图谱'),
                        const SizedBox(height: 6),
                        _buildMemoryMap(context, state, skin),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部导航栏（仪表盘是主页标签，无需返回按钮）
  Widget _buildTopNav(BuildContext context, ThemeVars skin) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Text('仪表盘', style: MwTypography.heading5.copyWith(color: skin.text1)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            color: skin.text1,
            tooltip: '分享学习海报',
            onPressed: () => _sharePoster(context),
          ),
        ],
      ),
    );
  }

  /// 当前词书卡片（封面 + 名称 + 学习进度条）
  Widget _buildCurrentBookCard(BuildContext context, Book? book, int learned, ThemeVars skin) {
    final progress = book == null || book.wordCount == 0 ? 0.0 : (learned / book.wordCount).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.lg),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 词书封面
              Container(
                width: 56,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [skin.pageBg, skin.cardBgAlt],
                  ),
                  borderRadius: BorderRadius.circular(context.design.radius.sm),
                  border: Border.all(color: skin.divider, width: 0.5),
                ),
                child: Center(
                  child: Text(
                    _shortName(book?.name ?? '未选择'),
                    style: MwTypography.micro.copyWith(color: skin.text2, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book?.name ?? '请先选择词书',
                      style: MwTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$learned',
                          style: TextStyle(
                            fontFamily: 'Charter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: skin.accent,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text('/ ${book?.wordCount ?? 0} 词已学', style: MwTypography.bodySm.copyWith(color: skin.text3)),
                      ],
                    ),
                  ],
                ),
              ),
              // 进度百分数
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(fontFamily: 'Charter', fontSize: 22, fontStyle: FontStyle.italic, color: skin.text3),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 学习进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: skin.divider,
                valueColor: AlwaysStoppedAnimation(skin.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 记忆图谱：总词量大数字 + FSRS 记忆状态堆叠条 + 图例
  Widget _buildMemoryMap(BuildContext context, LearningStatisticsState state, ThemeVars skin) {
    final stats = state.memoryStats;
    final newCount = stats['new'] ?? 0;
    final dueCount = stats['due'] ?? 0;
    final learningCount = stats['learning'] ?? 0;
    final matureCount = stats['mature'] ?? 0;
    final totalCount = stats['total'] ?? 0;

    final segments = <_MemorySegment>[
      _MemorySegment(label: '新词', value: newCount, color: MwColors.info),
      _MemorySegment(label: '学习中', value: learningCount, color: MwColors.warning),
      _MemorySegment(label: '待复习', value: dueCount, color: MwColors.danger),
      _MemorySegment(label: '已掌握', value: matureCount, color: MwColors.success),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 总词量大数字（视觉锚点）
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: totalCount),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text(
                '$value',
                style: TextStyle(
                  fontFamily: 'Charter',
                  fontSize: 56,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -2,
                  height: 1.05,
                  color: skin.text1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('个词在你的记忆里', style: MwTypography.bodySm.copyWith(color: skin.text3)),
          ],
        ),
        const SizedBox(height: 20),
        // 记忆状态堆叠条
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 12,
            child: totalCount == 0
                ? ColoredBox(color: skin.divider)
                : Row(
                    children: [
                      for (final segment in segments)
                        if (segment.value > 0)
                          Expanded(
                            flex: segment.value,
                            child: ColoredBox(color: segment.color),
                          ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 14),
        // 图例
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            for (final segment in segments)
              _LegendItem(color: segment.color, label: segment.label, value: '${segment.value}', skin: skin),
          ],
        ),
        if (totalCount == 0) ...[
          const SizedBox(height: 14),
          Text('开始学习后，这里会呈现你的记忆构成变化。', style: MwTypography.bodySm.copyWith(color: skin.text3)),
        ],
      ],
    );
  }

  String _shortName(String name) {
    return name.length > 4 ? name.substring(0, 4) : name;
  }

  /// 生成分享海报并分享
  Future<void> _sharePoster(BuildContext context) async {
    try {
      // 显示 loading
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('正在生成分享图...'), duration: Duration(seconds: 1)));

      // 获取尖叫币功能域提供的签到数据
      final scareCoinStore = context.read<ScareCoinStore>();
      // 海报总词数与统计面板同源（单一事实来源：FSRS 统计的 total）。
      final totalWords = context.read<LearningStatisticsState>().memoryStats['total'] ?? 0;
      final totalDays = (await scareCoinStore.checkinDates()).length;
      final streakDays = await scareCoinStore.streak();

      // 生成并分享
      await ShareImageService.generateAndShare(totalWords: totalWords, streakDays: streakDays, totalDays: totalDays);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('分享失败: $e')));
      }
    }
  }
}

/// 记忆状态堆叠条的单个分段。
class _MemorySegment {
  const _MemorySegment({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;
}

/// 图例项：色点 + 标签 + 数值
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, required this.value, required this.skin});

  final Color color;
  final String label;
  final String value;
  final ThemeVars skin;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: MwTypography.bodySm.copyWith(color: skin.text2)),
        const SizedBox(width: 5),
        Text(
          value,
          style: MwTypography.bodySm.copyWith(color: skin.text1, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
