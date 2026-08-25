// 结构化释义展示组件
// 将 JSON 解析后的 Definition 列表渲染为美观的释义卡片
import 'package:flutter/material.dart';

import '../data/wordbook_database.dart' show Definition;
import '../theme/skin_system.dart' show SkinProvider;
import '../tokens/design_tokens.dart';

/// 结构化释义展示
class DefinitionView extends StatelessWidget {
  final List<Definition> definitions;
  final bool compact;

  const DefinitionView({
    super.key,
    required this.definitions,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (definitions.isEmpty) {
      return Text('暂无释义', style: MistralTypography.bodySm);
    }

    final skin = SkinProvider.of(context);

    // 按词性分组
    final grouped = <String, List<Definition>>{};
    for (final def in definitions) {
      final pos = def.partOfSpeech.isEmpty ? '其他' : def.partOfSpeech;
      grouped.putIfAbsent(pos, () => []).add(def);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Padding(
          padding: EdgeInsets.only(bottom: compact ? 8 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 词性标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: skin.colors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.key,
                  style: MistralTypography.caption.copyWith(
                    color: skin.colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // 释义列表
              ...entry.value.asMap().entries.map((defEntry) {
                final idx = defEntry.key + 1;
                final def = defEntry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 释义行
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!compact) ...[
                            Text('$idx. ',
                              style: MistralTypography.bodySm.copyWith(
                                color: skin.colors.text3,
                              )),
                          ],
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: MistralTypography.body.copyWith(
                                  color: skin.colors.text1,
                                ),
                                children: [
                                  if (def.cnDef.isNotEmpty)
                                    TextSpan(
                                      text: def.cnDef,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  if (def.cnDef.isNotEmpty && def.enDef.isNotEmpty)
                                    TextSpan(
                                      text: '  ',
                                      style: TextStyle(color: skin.colors.text2),
                                    ),
                                  if (def.enDef.isNotEmpty)
                                    TextSpan(
                                      text: def.enDef,
                                      style: TextStyle(
                                        color: skin.colors.text2,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // 例句
                      if (!compact && def.examples.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ...def.examples.take(2).map((ex) => Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ',
                                style: MistralTypography.caption.copyWith(
                                  color: skin.colors.text3,
                                ),
                              ),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: MistralTypography.caption.copyWith(
                                      color: skin.colors.text2,
                                    ),
                                    children: [
                                      TextSpan(text: ex.en),
                                      if (ex.en.isNotEmpty && ex.cn.isNotEmpty)
                                        const TextSpan(text: '  '),
                                      TextSpan(
                                        text: ex.cn,
                                        style: TextStyle(
                                          color: skin.colors.text3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }
}
