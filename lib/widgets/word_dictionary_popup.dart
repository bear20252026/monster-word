// 内置字典弹出框：点击单词弹出释义小框
// 原版 App 交互：点击单词 → 弹出小框（单词+音标+释义+例句+收藏+跳转详情）
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/audio/audio_playback_state.dart';
import '../core/router/nav_utils.dart';
import 'package:word_app/core/parsers/example_parser.dart';
import '../models/word.dart';
import '../features/learning/presentation/learning_favorites_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../tokens/func_colors.dart';

/// 单词字典弹出框
/// 显示：单词 + 音标 + 释义 + 例句 + 收藏按钮 + 查看详情入口
class WordDictionaryPopup extends StatefulWidget {
  final Word word;
  final VoidCallback? onViewDetail;

  const WordDictionaryPopup({super.key, required this.word, this.onViewDetail});

  /// 显示弹出框（静态方法，方便调用）
  static Future<void> show(BuildContext context, Word word, {VoidCallback? onViewDetail}) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: MistralColors.black38,
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
  State<WordDictionaryPopup> createState() => _WordDictionaryPopupState();
}

class _WordDictionaryPopupState extends State<WordDictionaryPopup> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final favorites = context.watch<LearningFavoritesState>();
    final isFav = favorites.isFavorite(widget.word.word);
    final examples = ExampleParser.parse(widget.word.example);

    return GestureDetector(
      onTap: () {}, // 阻止点击穿透
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(maxWidth: 380),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: skin.colors.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: MistralColors.black15, blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(favorites, isFav, skin),
            if (widget.word.usPron.isNotEmpty || widget.word.ukPron.isNotEmpty) _buildPhonetics(skin),
            if (widget.word.interpret.isNotEmpty) _buildInterpret(skin),
            if (examples.isNotEmpty) _buildExample(skin, examples.first),
            _buildDetailLink(context, skin),
          ],
        ),
      ),
    );
  }

  /// 顶部：单词 + 收藏按钮
  Widget _buildHeader(LearningFavoritesState favorites, bool isFav, dynamic skin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: Row(
        children: [
          // 单词
          Expanded(
            child: Text(
              widget.word.word,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: skin.colors.text1),
            ),
          ),
          // 收藏按钮
          IconButton(
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? FuncColors.warning : skin.colors.text3, // 收藏星标：品牌金
              size: 22,
            ),
            tooltip: isFav ? '取消收藏' : '收藏',
            onPressed: () async {
              await favorites.toggle(widget.word.word);
            },
          ),
        ],
      ),
    );
  }

  /// 音标行（美式/英式）
  Widget _buildPhonetics(dynamic skin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          if (widget.word.usPron.isNotEmpty) ...[
            _PopupPhoneticPill(label: '美'),
            const SizedBox(width: 4),
            Text('/${widget.word.usPron}/', style: TextStyle(fontSize: 13, color: skin.colors.text3)),
          ],
          if (widget.word.ukPron.isNotEmpty) ...[
            const SizedBox(width: 12),
            _PopupPhoneticPill(label: '英'),
            const SizedBox(width: 4),
            Text('/${widget.word.ukPron}/', style: TextStyle(fontSize: 13, color: skin.colors.text3)),
          ],
        ],
      ),
    );
  }

  /// 释义文本
  Widget _buildInterpret(dynamic skin) {
    final meaningText = widget.word.hasStructuredDefinitions ? widget.word.formattedDefinitions : widget.word.interpret;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meaningText,
            style: TextStyle(fontSize: 15, color: skin.colors.text1, height: 1.5),
            maxLines: _isExpanded ? null : 3,
            overflow: _isExpanded ? null : TextOverflow.ellipsis,
          ),
          if (meaningText.length > 80)
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_isExpanded ? '收起' : '展开', style: TextStyle(fontSize: 13, color: skin.colors.accent)),
              ),
            ),
        ],
      ),
    );
  }

  /// 例句卡（高亮关键词 + 中文翻译）
  Widget _buildExample(dynamic skin, dynamic example) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: skin.colors.cardBgAlt, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: skin.colors.text1, height: 1.5),
              children: example.highlightedParts
                  .map(
                    (p) => TextSpan(
                      text: p.text,
                      style: p.highlight ? const TextStyle(fontWeight: FontWeight.bold) : null,
                    ),
                  )
                  .toList(),
            ),
          ),
          if (example.cn.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(example.cn, style: TextStyle(fontSize: 12, color: skin.colors.text3)),
          ],
          if (example.audioUrl != null && example.audioUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IconButton(
                icon: Icon(Icons.volume_up_outlined, color: skin.colors.accent, size: 20),
                onPressed: () => context.read<AudioPlaybackState>().playSentence(example.audioUrl!),
                tooltip: '播放例句',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
              ),
            ),
        ],
      ),
    );
  }

  /// 底部：查看详细释义链接
  Widget _buildDetailLink(BuildContext context, dynamic skin) {
    return GestureDetector(
      onTap: () {
        NavUtils.safePop(context); // 先关闭弹窗
        if (widget.onViewDetail != null) widget.onViewDetail!();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: skin.colors.divider, width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '查看详细释义',
              style: TextStyle(fontSize: 14, color: skin.colors.accent, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 12, color: skin.colors.accent),
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
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: skin.colors.cardBgAlt, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 11, color: skin.colors.text3)),
    );
  }
}
