// Monster Word — 共享词条行（词头 + 行内音标 + 首行释义 + 箭头）。
// 词单家族/词书单词页/词典派生词·近义词等"词形索引"场景的统一实现。
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';

/// 衬线词头词条行。
///
/// [onTap] 为空时整行不响应；[trailing] 自定义尾部动作（如发音/收藏按钮组），
/// 默认展示箭头。
class MwWordRow extends StatelessWidget {
  const MwWordRow({
    super.key,
    required this.word,
    this.phonetic,
    this.definition,
    this.onTap,
    this.trailing,
    this.divider = true,
  });

  final String word;
  final String? phonetic;
  final String? definition;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return ScaleDownOnPress(
      onTap: onTap,
      child: Material(
        color: skin.pageBg,
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: Text(
                                  word,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Charter',
                                    fontSize: MwTypography.heading5.fontSize,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: -0.3,
                                    color: skin.text1,
                                  ),
                                ),
                              ),
                              if (phonetic != null && phonetic!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '/${phonetic!}/',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: MwTypography.micro.copyWith(color: skin.text3),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (definition != null && definition!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              definition!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MwTypography.bodySm.copyWith(color: skin.text3, height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (trailing != null) trailing! else Icon(Icons.chevron_right, size: 18, color: skin.text3),
                  ],
                ),
              ),
              if (divider) Divider(height: 0.5, thickness: 0.5, indent: 16, color: skin.divider),
            ],
          ),
        ),
      ),
    );
  }
}
