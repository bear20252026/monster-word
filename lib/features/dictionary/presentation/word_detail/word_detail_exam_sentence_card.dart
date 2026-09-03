// 真题例句卡（单一事实来源）：词典详情页「真题」tab 与学习侧词详情页
// 「真题例句」区块共用同一卡片视觉（v2.7.49 收口此前两套样式）。
// 卡片：cardBg + 20px 圆角 + 0.5 divider；来源徽章：accent 0.12 淡底胶囊，
// 句子在上、徽章在下（与柯林斯/例句卡节奏一致）。
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

/// 真题例句卡
class ExamSentenceCard extends StatelessWidget {
  final String sentence;
  final String source;

  const ExamSentenceCard({super.key, required this.sentence, this.source = ''});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(context.design.spacing.md),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.lg),
        border: Border.all(color: skin.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sentence, style: MistralTypography.bodyMd.copyWith(color: skin.text1, height: 1.5)),
          if (source.isNotEmpty) ...[
            SizedBox(height: context.design.spacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: skin.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(context.design.radius.sm),
              ),
              child: Text(
                source,
                style: MistralTypography.micro.copyWith(color: skin.accent, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
