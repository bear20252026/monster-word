// 字典详情页 - 词组/搭配区块（从 word_detail_page.dart 拆出）
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/parsers/phrase_parser.dart';
import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

/// 词组/搭配分组列表（结构化展示）
class PhraseGroupList extends StatelessWidget {
  final String raw;
  final SkinSystem skin;
  const PhraseGroupList({super.key, required this.raw, required this.skin});

  @override
  Widget build(BuildContext context) {
    final groups = PhraseParser.parse(raw);
    if (groups.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.map((g) => _PhraseGroupCard(group: g, skin: skin)).toList(),
    );
  }
}

/// 单个词组分组卡片
class _PhraseGroupCard extends StatelessWidget {
  final PhraseGroup group;
  final SkinSystem skin;
  const _PhraseGroupCard({required this.group, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: skin.colors.pageBg,
        borderRadius: BorderRadius.circular(context.design.radius.md),
        border: Border.all(color: skin.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分组类型标签
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: skin.colors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(context.design.radius.sm),
            ),
            child: Text(
              group.type == 0 ? '固定搭配' : '常用词组',
              style: MistralTypography.caption.copyWith(color: skin.colors.accent),
            ),
          ),
          SizedBox(height: 8),
          // 词组列表
          ...group.items.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.en,
                          style: MistralTypography.bodyMd.copyWith(
                            color: skin.colors.text1,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // 发音按钮
                      GestureDetector(
                        onTap: () {
                          if (item.en.isNotEmpty) {
                            context.read<AudioPlaybackState>().playWord(item.en);
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.only(left: 6, top: 2),
                          child: Icon(Icons.volume_up_outlined, size: 16, color: skin.colors.accent),
                        ),
                      ),
                    ],
                  ),
                  if (item.cn.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(item.cn, style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                    ),
                  if (item.exams.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: item.exams
                            .map(
                              (e) => Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: skin.colors.cardBgAlt,
                                  borderRadius: BorderRadius.circular(context.design.radius.sm),
                                ),
                                child: Text(e, style: MistralTypography.micro.copyWith(color: skin.colors.text2)),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
