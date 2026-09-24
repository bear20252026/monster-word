// 字典详情页 - FSRS 记忆预测区块（从 word_detail_page.dart 拆出）
import 'package:flutter/material.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/application/review_schedule_reader.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/mw_card.dart';

/// FSRS 记忆预测卡片（从 word_detail_page.dart 拆出）
///
/// MEM/异步化：改为经 [ReviewScheduleReader.cardsForWords] 异步取卡——
/// 详情页词不受同步 LRU 缓存淘汰/读穿窗口影响，答案确定。
class FsrsPredictionCard extends StatefulWidget {
  final ReviewScheduleReader schedule;
  final Word word;

  const FsrsPredictionCard({super.key, required this.schedule, required this.word});

  @override
  State<FsrsPredictionCard> createState() => _FsrsPredictionCardState();
}

class _FsrsPredictionCardState extends State<FsrsPredictionCard> {
  Future<Map<String, FsrsCard?>>? _cardFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FsrsPredictionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.word != widget.word.word || oldWidget.schedule != widget.schedule) {
      _load();
    }
  }

  void _load() {
    _cardFuture = widget.schedule.cardsForWords([widget.word.word]);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return FutureBuilder<Map<String, FsrsCard?>>(
      future: _cardFuture,
      builder: (context, snap) {
        final card = snap.data?[widget.word.word];
        return _buildBody(context, skin, card);
      },
    );
  }

  Widget _buildBody(BuildContext context, SkinSystem skin, FsrsCard? card) {
    if (card == null || card.isNew) {
      return MwCard(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.psychology_outlined, color: skin.colors.accent, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text('新词 — 开始学习后将生成记忆预测', style: MwTypography.bodyMd.copyWith(color: skin.colors.text2)),
            ),
          ],
        ),
      );
    }
    final prediction = card;
    final r = prediction.stability;
    final statusColor = r < 3
        ? context.skin.colors.danger
        : r < 7
        ? MwColors.warning
        : r < 14
        ? MwColors.info
        : context.skin.colors.success;
    return MwCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, color: skin.colors.accent, size: 20),
              SizedBox(width: 8),
              Text('记忆预测', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(context.design.radius.sm),
                ),
                child: Text(
                  r < 3
                      ? '即将遗忘'
                      : r < 7
                      ? '模糊'
                      : r < 14
                      ? '一般'
                      : '牢固',
                  style: MwTypography.caption.copyWith(color: statusColor),
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
        Text(label, style: MwTypography.caption.copyWith(color: skin.colors.text3)),
        SizedBox(height: 2),
        Text(
          value,
          style: MwTypography.bodyMd.copyWith(color: skin.colors.text1, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
