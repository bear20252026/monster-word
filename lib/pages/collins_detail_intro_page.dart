// 柯林斯词典详情页：富格式释义展示
// 橙色单词标题 + 评分圆点 + 考试标签 + 英文释义 + See also + 例句
import 'package:flutter/material.dart';

import '../models/word_data_models.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class CollinsDetailIntroPage extends StatelessWidget {
  final String word;
  final CollinsWordDetail? detail;
  // 兼容旧接口
  final String? definition;
  final String? examples;

  const CollinsDetailIntroPage({super.key, required this.word, this.detail, this.definition, this.examples});

  static const routeName = '/collins_detail';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final d = detail;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin, context),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: d != null ? _buildRichContent(skin, d) : _buildFallbackContent(skin),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 富格式内容
  Widget _buildRichContent(SkinSystem skin, CollinsWordDetail d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 橙色单词标题
        Text(
          d.word,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: skin.colors.accent),
        ),
        const SizedBox(height: 10),

        // 2. 评分圆点 + 考试标签
        Row(
          children: [
            _buildRatingDots(d.rating, skin),
            if (d.tags.isNotEmpty) ...[const SizedBox(width: 12), ...d.tags.map((tag) => _buildTag(tag, skin))],
          ],
        ),
        const SizedBox(height: 16),

        // 3. 词性 + 英文释义
        if (d.wordType.isNotEmpty) ...[
          Text(
            d.wordType,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: skin.colors.text2),
          ),
          const SizedBox(height: 6),
        ],
        if (d.definition.isNotEmpty) ...[
          Text(d.definition, style: TextStyle(fontSize: 15, color: skin.colors.text1, height: 1.6)),
          const SizedBox(height: 20),
        ],

        // 4. See also 链接
        if (d.seeAlso.isNotEmpty) ...[_buildSeeAlsoSection(skin, d.seeAlso), const SizedBox(height: 20)],

        // 5. 例句列表
        if (d.examples.isNotEmpty) ...[_buildExamplesSection(skin, d.examples)],
      ],
    );
  }

  /// 评分圆点（品牌色填充 + 分割线色空心）
  Widget _buildRatingDots(int rating, SkinSystem skin) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final filled = i < rating;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: filled ? skin.colors.accent : skin.colors.divider),
          ),
        );
      }),
    );
  }

  /// 考试标签（CET4 / TEM4 等）
  Widget _buildTag(String tag, SkinSystem skin) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: skin.colors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: skin.colors.accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        tag,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: skin.colors.accent),
      ),
    );
  }

  /// See also 区域
  Widget _buildSeeAlsoSection(SkinSystem skin, List<String> words) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'See also',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: skin.colors.text2),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: words
              .map(
                (w) => GestureDetector(
                  onTap: () {
                    // TODO: 跳转到相关单词详情
                  },
                  child: Text(
                    w,
                    style: TextStyle(fontSize: 14, color: skin.colors.teal, decoration: TextDecoration.underline),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  /// 例句区域
  Widget _buildExamplesSection(SkinSystem skin, List<CollinsExample> examples) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '例句',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: skin.colors.text1),
        ),
        const SizedBox(height: 8),
        ...examples.map((ex) => _buildExampleItem(skin, ex)),
      ],
    );
  }

  /// 单条例句
  Widget _buildExampleItem(SkinSystem skin, CollinsExample ex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: skin.colors.cardBg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8, top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: skin.colors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '例',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: skin.colors.accent),
                ),
              ),
              Expanded(
                child: Text(ex.english, style: TextStyle(fontSize: 14, color: skin.colors.text1, height: 1.5)),
              ),
            ],
          ),
          if (ex.chinese.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 31),
              child: Text(ex.chinese, style: TextStyle(fontSize: 13, color: skin.colors.text3, height: 1.4)),
            ),
          ],
        ],
      ),
    );
  }

  /// 兼容旧接口的回退内容
  Widget _buildFallbackContent(SkinSystem skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(word, style: MistralTypography.heading3.copyWith(color: skin.colors.text1)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: MistralColors.cream, borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Text('柯林斯词典', style: MistralTypography.micro.copyWith(color: MistralColors.primary)),
        ),
        const SizedBox(height: 24),
        if (definition != null) ...[
          Text('释义', style: MistralTypography.bodyBold.copyWith(color: skin.colors.text1)),
          const SizedBox(height: 8),
          Text(definition!, style: MistralTypography.body.copyWith(color: skin.colors.text1, height: 1.6)),
          const SizedBox(height: 24),
        ],
        if (examples != null) ...[
          Text('例句', style: MistralTypography.bodyBold.copyWith(color: skin.colors.text1)),
          const SizedBox(height: 8),
          Text(
            examples!,
            style: MistralTypography.body.copyWith(color: skin.colors.text3, height: 1.6, fontStyle: FontStyle.italic),
          ),
        ],
      ],
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
          Text('柯林斯词典', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }
}
