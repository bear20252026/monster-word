// 字典详情页 - FSRS 记忆预测区块（从 word_detail_page.dart 拆出）
import 'package:flutter/material.dart';

import 'package:word_app/features/learning/application/review_schedule_reader.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/mw_card.dart';

/// FSRS 记忆预测卡片（从 word_detail_page.dart 拆出）
class FsrsPredictionCard extends StatelessWidget {
  final ReviewScheduleReader schedule;
  final Word word;

  const FsrsPredictionCard({super.key, required this.schedule, required this.word});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final card = schedule.cardFor(word.word);
    if (card == null || card.isNew) {
      return MwCard(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.psychology_outlined, color: skin.colors.accent, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text('新词 — 开始学习后将生成记忆预测', style: MistralTypography.bodyMd.copyWith(color: skin.colors.text2)),
            ),
          ],
        ),
      );
    }
    final prediction = schedule.cardFor(word.word);
    if (prediction == null) return const SizedBox.shrink();
    final r = prediction.stability;
    final statusColor = r < 3
        ? Colors.red
        : r < 7
        ? Colors.orange
        : r < 14
        ? Colors.blue
        : Colors.green;
    return MwCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, color: skin.colors.accent, size: 20),
              SizedBox(width: 8),
              Text('记忆预测', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  r < 3
                      ? '即将遗忘'
                      : r < 7
                      ? '模糊'
                      : r < 14
                      ? '一般'
                      : '牢固',
                  style: MistralTypography.caption.copyWith(color: statusColor),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _FsrsStat(label: '难度', value: prediction.difficulty.toStringAsFixed(1)),
              SizedBox(width: 16),
              _FsrsStat(label: '稳定性', value: '${prediction.stability.toStringAsFixed(1)} 天'),
              SizedBox(width: 16),
              _FsrsStat(label: '复习次数', value: '${prediction.reviewCount}'),
            ],
          ),
        ],
      ),
    );
  }
}

/// FSRS 记忆统计小部件
class _FsrsStat extends StatelessWidget {
  final String label;
  final String value;
  const _FsrsStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MistralTypography.caption.copyWith(color: skin.colors.text3)),
        SizedBox(height: 2),
        Text(
          value,
          style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
