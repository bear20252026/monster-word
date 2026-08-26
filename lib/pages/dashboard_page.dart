// 仪表盘页：顶部导航 + 正在学习(词书卡片+进度条) + 我的数据(学习时长/单词量)
// 已接入 SkinSystem 主题
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../hooks/responsive.dart';
import '../models/book.dart';
import '../pages/scare_coin_history_page.dart';
import '../services/share_image_service.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const routeName = '/dashboard';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LearningState>();
    final book = state.currentBook;
    final learned = state.learnedNum;
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
                        // 正在学习
                        Text(
                          '正在学习',
                          style: MistralTypography.heading4.copyWith(color: skin.text1),
                        ),
                        const SizedBox(height: 12),
                        _buildCurrentBookCard(context, state, book, learned, skin),
                        const SizedBox(height: 24),
                        _buildMyDataSection(context, state, book, learned, skin),
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
          Text(
            '仪表盘',
            style: MistralTypography.heading5.copyWith(color: skin.text1),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.share, size: 20),
            color: skin.text1,
            tooltip: '分享',
            onPressed: () => _sharePoster(context),
          ),
        ],
      ),
    );
  }

  /// 当前词书卡片（封面 + 名称 + 学习进度条）
  Widget _buildCurrentBookCard(BuildContext context, LearningState state, Book? book, int learned, ThemeVars skin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: Text(
                    _shortName(book?.name ?? '未选择'),
                    style: MistralTypography.micro.copyWith(
                      color: AppColors.white100,
                      fontWeight: FontWeight.bold,
                    ),
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
                      style: MistralTypography.bodyMd.copyWith(
                        color: skin.text1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${book?.wordCount ?? 0} 词',
                      style: MistralTypography.bodySm.copyWith(color: skin.text3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 学习进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: book == null || book.wordCount == 0 ? 0 : learned / book.wordCount,
              minHeight: 8,
              backgroundColor: skin.divider,
              valueColor: AlwaysStoppedAnimation(skin.success),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '已学习 $learned',
                style: MistralTypography.bodySm.copyWith(color: skin.text3),
              ),
              const Spacer(),
              Text(
                '总词数 ${book?.wordCount ?? 0}',
                style: MistralTypography.bodySm.copyWith(color: skin.text3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 我的数据统计卡片
  Widget _buildMyDataSection(BuildContext context, LearningState state, Book? book, int learned, ThemeVars skin) {
    final resp = context.responsive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '我的数据',
          style: MistralTypography.heading4.copyWith(color: skin.text1),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: skin.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: skin.divider),
          ),
          // FSRS-6 记忆统计（基于精确记忆曲线）
          child: _buildFsrsStats(context, state, skin, resp),
        ),
      ],
    );
  }

  /// FSRS-6 记忆统计面板
  Widget _buildFsrsStats(BuildContext context, LearningState state, ThemeVars skin, AppResponsive resp) {
    final stats = state.memoryStats;
    final todayStats = state.todayStats;
    final newCount = stats['new'] ?? 0;
    final dueCount = stats['due'] ?? 0;
    final learningCount = stats['learning'] ?? 0;
    final matureCount = stats['mature'] ?? 0;
    final totalCount = stats['total'] ?? 0;

    if (resp.isDesktop) {
      return Row(
        children: [
          Expanded(child: _DataItem(label: '新词', value: '$newCount', color: Colors.blue)),
          Container(width: 1, height: 40, color: skin.divider),
          Expanded(child: _DataItem(label: '学习中', value: '$learningCount', color: Colors.orange)),
          Container(width: 1, height: 40, color: skin.divider),
          Expanded(child: _DataItem(label: '待复习', value: '$dueCount', color: Colors.red)),
          Container(width: 1, height: 40, color: skin.divider),
          Expanded(child: _DataItem(label: '已掌握', value: '$matureCount', color: Colors.green)),
          Container(width: 1, height: 40, color: skin.divider),
          Expanded(child: _DataItem(label: '总词汇', value: '$totalCount')),
        ],
      );
    }
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DataItem(label: '新词', value: '$newCount', color: Colors.blue),
            _DataItem(label: '学习中', value: '$learningCount', color: Colors.orange),
            _DataItem(label: '待复习', value: '$dueCount', color: Colors.red),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DataItem(label: '已掌握', value: '$matureCount', color: Colors.green),
            _DataItem(label: '总词汇', value: '$totalCount'),
            _DataItem(label: '今日已学', value: '${todayStats['learned'] ?? 0}'),
          ],
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在生成分享图...'), duration: Duration(seconds: 1)),
      );

      // 获取用户数据（临时使用 ScareCoinLedger 获取签到数据）
      final totalDays = (await ScareCoinLedger.checkinDates()).length;
      final streakDays = await ScareCoinLedger.streak();

      // 生成并分享
      await ShareImageService.generateAndShare(
        totalWords: 25000, // 词库总数作为学习参考
        streakDays: streakDays,
        totalDays: totalDays,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }
}

class _DataItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _DataItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Column(
      children: [
        Text(
          value,
          style: MistralTypography.heading3.copyWith(
            color: color ?? skin.success,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: MistralTypography.bodySm.copyWith(color: skin.text3),
        ),
      ],
    );
  }
}
