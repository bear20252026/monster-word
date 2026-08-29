// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 SentenceDetailActivity
// 例句详情页：显示单词的完整例句及翻译
import 'package:flutter/material.dart';

import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';

class SentenceDetailPage extends StatelessWidget {
  final String word;
  final String sentence;
  final String? translation;
  final String? source;

  const SentenceDetailPage({super.key, required this.word, required this.sentence, this.translation, this.source});

  static const routeName = '/sentence_detail';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin, context),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 单词标题
                    Text(word, style: MistralTypography.heading3.copyWith(color: skin.colors.text1)),
                    const SizedBox(height: 24),
                    // 例句
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: skin.colors.cardBgAlt,
                        borderRadius: BorderRadius.circular(context.design.radius.lg),
                        border: Border.all(color: skin.colors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.format_quote, size: 20, color: MistralColors.primary),
                              const SizedBox(width: 8),
                              Text('例句', style: MistralTypography.bodyBold.copyWith(color: skin.colors.text1)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(sentence, style: MistralTypography.body.copyWith(color: skin.colors.text1, height: 1.6)),
                          if (translation != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              translation!,
                              style: MistralTypography.body.copyWith(color: skin.colors.text3, height: 1.6),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (source != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.source, size: 16, color: skin.colors.text3),
                          const SizedBox(width: 8),
                          Text('来源：$source', style: MistralTypography.micro.copyWith(color: skin.colors.text3)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin, BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('例句详情', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.volume_up_outlined, color: skin.colors.text1, size: 22),
            onPressed: () {
              // TODO: 播放语音
            },
          ),
        ],
      ),
    );
  }
}

