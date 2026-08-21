// 由账号4生成
// 仪表盘页：1:1 复刻原版 activity_dashboard.xml
// 结构：顶部导航 + 正在学习(词书卡片+进度条) + 我的数据(学习时长/单词量)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/learning_state.dart';
import '../theme/app_theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const routeName = '/dashboard';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LearningState>();
    final book = state.currentBook;
    final learned = state.learnedNum;

    return Scaffold(
      backgroundColor: AppColors.cardBg,
      body: SafeArea(
        child: Column(
          children: [
            // ===== 顶部导航栏（原版 CustomHeadView："仪表盘"）=====
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: AppColors.black87,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '仪表盘',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share, size: 20),
                    color: AppColors.black87,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.dividerGrey),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimens.pageCommonMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== 正在学习（原版 Section 标题）=====
                    const Text(
                      '正在学习',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ===== 当前词书卡片（原版 lib_container + card_common_bg）=====
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.dividerGrey),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // 词书封面（原版 lib_icons_view）
                              Container(
                                width: 56,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.mainBgTop,
                                      AppColors.mainBgBottom,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    _shortName(book?.name ?? '未选择'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
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
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${book?.wordCount ?? 0} 词',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // ===== 学习进度条（原版 word_learn_progress）=====
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: book == null || book.wordCount == 0
                                  ? 0
                                  : learned / book.wordCount,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.successGreen,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // ===== 已学习/总词数（原版 tv_learned_num/tv_total_word_num）=====
                          Row(
                            children: [
                              Text(
                                '已学习 $learned',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '总词数 ${book?.wordCount ?? 0}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // ===== 我的数据（原版 Section 标题）=====
                    const Text(
                      '我的数据',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 数据卡片
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.dividerGrey),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _DataItem(label: '今日学习', value: '$learned'),
                          _DataItem(label: '待复习', value: '${state.dueCount}'),
                          _DataItem(label: '词书', value: '${book == null ? 0 : 1}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortName(String name) {
    return name.length > 4 ? name.substring(0, 4) : name;
  }
}

/// 数据项（原版 dashboard 数据展示）
class _DataItem extends StatelessWidget {
  final String label;
  final String value;
  const _DataItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.successGreen,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
