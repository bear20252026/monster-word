// 联想记忆中间页：展示单词的联想记忆方法
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

class LinkedMeMiddlePage extends StatelessWidget {
  final String word;
  final String? association;

  const LinkedMeMiddlePage({super.key, required this.word, this.association});

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
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 单词
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: MwColors.cream,
                        borderRadius: BorderRadius.circular(context.design.radius.xl),
                      ),
                      child: Column(
                        children: [
                          Text(word, style: MwTypography.heading2.copyWith(color: MwColors.ink)),
                          SizedBox(height: 8),
                          Text('联想记忆', style: MwTypography.body.copyWith(color: MwColors.slate)),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    // 联想内容
                    if (association != null) ...[
                      Text('记忆方法', style: MwTypography.bodyBold.copyWith(color: skin.colors.text1)),
                      SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: skin.colors.cardBgAlt,
                          borderRadius: BorderRadius.circular(context.design.radius.lg),
                          border: Border.all(color: skin.colors.divider),
                        ),
                        child: Text(
                          association!,
                          style: MwTypography.body.copyWith(color: skin.colors.text1, height: 1.8),
                        ),
                      ),
                    ] else ...[
                      Center(
                        child: Column(
                          children: [
                            SizedBox(height: 80),
                            Icon(Icons.lightbulb_outline, size: 64, color: skin.colors.text3),
                            SizedBox(height: 16),
                            Text('暂无联想记忆', style: MwTypography.body.copyWith(color: skin.colors.text3)),
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
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            tooltip: '返回',
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 4),
          const Text('联想记忆', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
