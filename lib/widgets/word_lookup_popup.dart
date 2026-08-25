// 内置字典弹窗：长按单词弹出释义小框
// 样式：圆角 + 阴影 + 半透明背景
// 点击可进入字典详情页
import 'dart:ui';
import 'package:flutter/material.dart';

import '../data/wordbook_database.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

/// 长按单词弹出的释义小框
///
/// 使用方式：
/// ```dart
/// WordLookupPopup(
///   word: 'example',
///   child: Text('example'),
/// )
/// ```
class WordLookupPopup extends StatelessWidget {
  final String word;
  final Widget child;

  const WordLookupPopup({
    super.key,
    required this.word,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) => _showPopup(context, details.globalPosition),
      child: child,
    );
  }

  void _showPopup(BuildContext context, Offset position) async {
    // 查询单词数据
    final wordData = await _lookupWord(word);
    if (!context.mounted) return;

    // 计算弹窗位置（避免超出屏幕）
    final screenSize = MediaQuery.of(context).size;
    final popupWidth = 280.0;
    final popupHeight = 160.0;

    double left = position.dx - popupWidth / 2;
    double top = position.dy - popupHeight - 16; // 显示在长按位置上方

    // 边界修正
    if (left < 16) left = 16;
    if (left + popupWidth > screenSize.width - 16) {
      left = screenSize.width - popupWidth - 16;
    }
    if (top < 50) {
      // 上方空间不足，显示在下方
      top = position.dy + 16;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'lookup_popup',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, _) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return Stack(
          children: [
            // 点击空白关闭
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(color: Colors.transparent),
            ),
            // 弹窗主体
            Positioned(
              left: left,
              top: top,
              child: FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween(begin: 0.9, end: 1.0).animate(curved),
                  child: _PopupCard(
                    word: word,
                    wordData: wordData,
                    onTap: () {
                      Navigator.pop(ctx);
                      // 跳转字典详情页
                      Navigator.pushNamed(context, '/word_detail', arguments: wordData);
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 查询单词数据
  Future<Word?> _lookupWord(String word) async {
    try {
      return await WordBookDatabase.instance.getWord(word);
    } catch (e) {
      debugPrint('Word lookup error: $e');
      return null;
    }
  }
}

/// 弹窗卡片
class _PopupCard extends StatelessWidget {
  final String word;
  final Word? wordData;
  final VoidCallback onTap;

  const _PopupCard({
    required this.word,
    required this.wordData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: skin.cardBg.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: skin.divider.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: wordData != null
                  ? _buildContent(skin)
                  : _buildNotFound(skin),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeVars skin) {
    final w = wordData!;
    final meaningText = w.hasStructuredDefinitions
        ? w.formattedDefinitions
        : w.interpret;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 单词 + 音标
        Row(
          children: [
            Text(
              w.word,
              style: MistralTypography.heading5.copyWith(
                color: skin.text1,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (w.usPron.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '/${w.usPron}/',
                style: MistralTypography.body.copyWith(
                  color: skin.text3,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // 释义（优先结构化释义）
        if (meaningText.isNotEmpty)
          Text(
            meaningText,
            style: MistralTypography.body.copyWith(
              color: skin.text2,
              fontSize: 14,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 10),
        // 底部提示
        Row(
          children: [
            Icon(Icons.touch_app, size: 14, color: skin.text3),
            const SizedBox(width: 4),
            Text(
              '点击查看详情',
              style: MistralTypography.micro.copyWith(color: skin.text3),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 12, color: skin.text3),
          ],
        ),
      ],
    );
  }

  Widget _buildNotFound(ThemeVars skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          word,
          style: MistralTypography.heading5.copyWith(
            color: skin.text1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '未找到该单词',
          style: MistralTypography.body.copyWith(color: skin.text3),
        ),
      ],
    );
  }
}

/// 便捷扩展：给任意 Text widget 添加长按查词
extension WordLookupExtension on Widget {
  /// 包裹为可长按查词的 widget
  Widget withWordLookup(String word) {
    return WordLookupPopup(word: word, child: this);
  }
}
