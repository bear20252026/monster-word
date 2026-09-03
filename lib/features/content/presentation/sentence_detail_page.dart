// 由 Claude 团队生成 | Monster Word App

// 例句详情页：显示单词的完整例句及翻译
// 发音走既有端口 AudioPlaybackState（例句本身无音频 URL 时播所属单词，有道 TTS 回退）。
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

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
                    Text(word, style: MwTypography.heading3.copyWith(color: skin.colors.text1)),
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
                              Icon(Icons.format_quote, size: 20, color: MwColors.primary),
                              const SizedBox(width: 8),
                              Text('例句', style: MwTypography.bodyBold.copyWith(color: skin.colors.text1)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(sentence, style: MwTypography.body.copyWith(color: skin.colors.text1, height: 1.6)),
                          if (translation != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              translation!,
                              style: MwTypography.body.copyWith(color: skin.colors.text3, height: 1.6),
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
                          Text('来源：$source', style: MwTypography.micro.copyWith(color: skin.colors.text3)),
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
          Text('例句详情', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.volume_up_outlined, color: skin.colors.text1, size: 22),
            onPressed: () {
              // 例句本身无音频 URL，播所属单词发音（有道 TTS 回退）
              if (word.isNotEmpty) {
                context.read<AudioPlaybackState>().playWord(word);
              }
            },
          ),
        ],
      ),
    );
  }
}
