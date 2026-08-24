// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 LinkedMEMiddleActivty
// 联想记忆中间页：展示单词的联想记忆方法
import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class LinkedMeMiddlePage extends StatelessWidget {
  final String word;
  final String? association;

  const LinkedMeMiddlePage({
    super.key,
    required this.word,
    this.association,
  });

  static const routeName = '/linked_me';

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
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 单词
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: MistralColors.cream,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Column(
                        children: [
                          Text(word,
                            style: MistralTypography.heading2.copyWith(color: MistralColors.ink)),
                          const SizedBox(height: 8),
                          Text('联想记忆',
                            style: MistralTypography.body.copyWith(color: MistralColors.slate)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 联想内容
                    if (association != null) ...[
                      Text('记忆方法', style: MistralTypography.bodyBold.copyWith(color: skin.colors.text1)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: skin.colors.cardBgAlt,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: skin.colors.divider),
                        ),
                        child: Text(association!,
                          style: MistralTypography.body.copyWith(
                            color: skin.colors.text1,
                            height: 1.8,
                          )),
                      ),
                    ] else ...[
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 80),
                            Icon(Icons.lightbulb_outline, size: 64, color: skin.colors.text3),
                            const SizedBox(height: 16),
                            Text('暂无联想记忆',
                              style: MistralTypography.body.copyWith(color: skin.colors.text3)),
                          ],
                        ),
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
          Text('联想记忆', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }
}
