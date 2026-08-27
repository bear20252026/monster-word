// 由 Claude 团队生成 | Monster Word App

// 词根词缀Tab组件
// 展示单词的词根、前缀、后缀信息及相关派生词

import 'package:flutter/material.dart';

import '../models/word_root_model.dart';
import '../theme/skin_system.dart';

/// 词根词缀Tab组件
class WordRootTab extends StatelessWidget {
  final String wordRootJson;

  const WordRootTab({super.key, required this.wordRootJson});

  @override
  Widget build(BuildContext context) {
    final wordRoot = WordRootData.fromJson(wordRootJson);
    final skin = context.skin.colors;

    if (!wordRoot.hasData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: skin.text3),
            const SizedBox(height: 12),
            Text('暂无词根数据', style: TextStyle(fontSize: 16, color: skin.text3)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 词根结构图
          _buildRootStructure(wordRoot, skin),
          const SizedBox(height: 24),

          // 词根详细解释
          _buildRootDetails(wordRoot, skin),
          const SizedBox(height: 24),

          // 记忆技巧
          _buildMemoryTips(wordRoot, skin),
        ],
      ),
    );
  }

  /// 构建词根结构图
  Widget _buildRootStructure(WordRootData wordRoot, ThemeVars skin) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '词根结构',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: skin.text1),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: wordRoot.components.map((component) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(component.colorValue).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(component.colorValue).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      component.typeName,
                      style: TextStyle(fontSize: 12, color: Color(component.colorValue), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      component.text,
                      style: TextStyle(fontSize: 14, color: skin.text1, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 构建词根详细解释
  Widget _buildRootDetails(WordRootData wordRoot, ThemeVars skin) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '词根解释',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: skin.text1),
          ),
          const SizedBox(height: 12),

          // 前缀
          if (wordRoot.prefix.isNotEmpty) ...[
            _buildDetailItem('前缀', wordRoot.prefix, skin.success, skin),
            const SizedBox(height: 8),
          ],

          // 词根
          ...wordRoot.roots.map((root) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildDetailItem('词根', root, skin.teal, skin),
            );
          }),

          // 后缀
          if (wordRoot.suffix.isNotEmpty) ...[_buildDetailItem('后缀', wordRoot.suffix, skin.accent, skin)],
        ],
      ),
    );
  }

  /// 构建详细解释项
  Widget _buildDetailItem(String type, String content, Color color, ThemeVars skin) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
          child: Text(
            type,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(content, style: TextStyle(fontSize: 14, color: skin.text1, height: 1.5)),
        ),
      ],
    );
  }

  /// 构建记忆技巧
  Widget _buildMemoryTips(WordRootData wordRoot, ThemeVars skin) {
    // 生成记忆技巧
    final tips = _generateMemoryTips(wordRoot);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 20, color: skin.accent),
              const SizedBox(width: 8),
              Text(
                '记忆技巧',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: skin.text1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map((tip) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 16, color: skin.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tip, style: TextStyle(fontSize: 14, color: skin.text1, height: 1.5)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 生成记忆技巧
  List<String> _generateMemoryTips(WordRootData wordRoot) {
    final tips = <String>[];

    if (wordRoot.roots.isNotEmpty) {
      for (final root in wordRoot.roots) {
        // 解析词根含义
        final parts = root.split('=');
        if (parts.length == 2) {
          final rootWord = parts[0].trim();
          final meaning = parts[1].trim();
          tips.add('词根 "$rootWord" 表示"$meaning"，记住这个含义可以帮助理解相关单词。');
        } else {
          tips.add('词根 "$root" 是理解这个单词的关键。');
        }
      }
    }

    if (wordRoot.prefix.isNotEmpty) {
      tips.add('前缀 "${wordRoot.prefix}" 可以改变词根的含义。');
    }

    if (wordRoot.suffix.isNotEmpty) {
      tips.add('后缀 "${wordRoot.suffix}" 通常决定单词的词性。');
    }

    if (tips.isEmpty) {
      tips.add('尝试将单词拆分为词根、前缀和后缀来记忆。');
    }

    return tips;
  }
}
