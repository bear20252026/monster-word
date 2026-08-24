// 内置字典弹出框：点击单词弹出释义小框
// 原版 App 交互：点击单词 → 弹出小框（单词+音标+释义+例句+收藏+跳转详情）
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/example_parser.dart';
import '../data/wordbook_database.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';

/// 单词字典弹出框
/// 显示：单词 + 音标 + 释义 + 例句 + 收藏按钮 + 查看详情入口
class WordDictionaryPopup extends StatelessWidget {
  final Word word;
  final VoidCallback? onViewDetail;

  const WordDictionaryPopup({
    super.key,
    required this.word,
    this.onViewDetail,
  });

  /// 显示弹出框（静态方法，方便调用）
  static Future<void> show(BuildContext context, Word word, {VoidCallback? onViewDetail}) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, a) => Center(
        child: WordDictionaryPopup(word: word, onViewDetail: onViewDetail),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final state = context.watch<LearningState>();
    final isFav = state.isFavorite(word.word);
    final examples = ExampleParser.parse(word.example);

    return GestureDetector(
      onTap: () {}, // 阻止点击穿透
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(maxWidth: 380),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：单词 + 收藏按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  // 单词
                  Expanded(
                    child: Text(
                      word.word,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  // 收藏按钮
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.star : Icons.star_border,
                      color: isFav ? Colors.amber : const Color(0xFF999999),
                      size: 22,
                    ),
                    tooltip: isFav ? '取消收藏' : '收藏',
                    onPressed: () async {
                      await state.toggleFavorite(word.word);
                    },
                  ),
                ],
              ),
            ),
            // 音标
            if (word.usPron.isNotEmpty || word.ukPron.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    if (word.usPron.isNotEmpty) ...[
                      _PopupPhoneticPill(label: '美'),
                      const SizedBox(width: 4),
                      Text(
                        '/${word.usPron}/',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ],
                    if (word.ukPron.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      _PopupPhoneticPill(label: '英'),
                      const SizedBox(width: 4),
                      Text(
                        '/${word.ukPron}/',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            // 释义
            if (word.interpret.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  word.interpret,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF333333),
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // 例句（如果有）
            if (examples.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF333333),
                          height: 1.5,
                        ),
                        children: examples.first.highlightedParts
                            .map(
                              (p) => TextSpan(
                                text: p.text,
                                style: p.highlight
                                    ? const TextStyle(fontWeight: FontWeight.bold)
                                    : null,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    if (examples.first.cn.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        examples.first.cn,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            // 底部：查看详细释义链接
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop(); // 先关闭弹窗
                if (onViewDetail != null) onViewDetail!();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '查看详细释义',
                      style: TextStyle(
                        fontSize: 14,
                        color: skin.colors.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: skin.colors.accent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 音标胶囊标签
class _PopupPhoneticPill extends StatelessWidget {
  final String label;
  const _PopupPhoneticPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
      ),
    );
  }
}
