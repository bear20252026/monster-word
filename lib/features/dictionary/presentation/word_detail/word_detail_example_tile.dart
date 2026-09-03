// 字典详情页 - 例句条目（带收藏与发音，从 word_detail_page.dart 拆出）
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';

import 'package:word_app/core/parsers/example_parser.dart';
import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/features/word_browse/application/sentence_favorites_store.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/text_generate_effect.dart';

/// 例句条目（带收藏按钮）
class ExampleTile extends StatefulWidget {
  final ExampleSentence example;
  final SkinSystem skin;
  final String word;
  final int wordId;

  const ExampleTile(this.example, this.skin, {super.key, required this.word, required this.wordId});

  @override
  State<ExampleTile> createState() => ExampleTileState();
}

class ExampleTileState extends State<ExampleTile> with SingleTickerProviderStateMixin {
  bool _isFav = false;
  late AnimationController _favAnimController;
  late Animation<double> _favScaleAnim;

  @override
  void initState() {
    super.initState();
    _favAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _favScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(_favAnimController);
    _checkFavStatus();
  }

  @override
  void dispose() {
    _favAnimController.dispose();
    super.dispose();
  }

  void _checkFavStatus() {
    // 使用句子的唯一标识（英文内容的hash）作为sentenceId
    final sentenceId = widget.example.en.hashCode.toString();
    final favStore = context.read<SentenceFavoritesStore>();
    favStore.isFavorite(wordId: widget.wordId, sentenceId: sentenceId).then((v) {
      if (mounted) setState(() => _isFav = v);
    });
  }

  Future<void> _toggleFav() async {
    final sentenceId = widget.example.en.hashCode.toString();
    final store = context.read<SentenceFavoritesStore>();
    final messenger = ScaffoldMessenger.of(context);

    // 触觉反馈 + 弹性动画
    unawaited(HapticFeedback.lightImpact());
    unawaited(_favAnimController.forward(from: 0.0));

    await store.toggle(
      wordId: widget.wordId,
      sentenceId: sentenceId,
      english: widget.example.en,
      chinese: widget.example.cn,
      source: widget.example.source,
    );

    if (mounted) {
      // 直接获取新状态，不设中间值避免闪烁
      final newStatus = await store.isFavorite(wordId: widget.wordId, sentenceId: sentenceId);
      if (mounted) setState(() => _isFav = newStatus);

      messenger.showSnackBar(
        SnackBar(content: Text(_isFav ? '已收藏到句库' : '已取消收藏'), duration: const Duration(seconds: 1)),
      );
    }
  }

  /// 播放例句音频（audio.beingfine.cn 的完整 URL）。
  void _playExampleAudio() {
    final url = widget.example.audioUrl;
    if (url == null || url.isEmpty) return;
    context.read<AudioPlaybackState>().playSentence(url);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.skin.colors.pageBg,
        borderRadius: BorderRadius.circular(context.design.radius.sm),
        border: Border.all(color: widget.skin.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: MwTypography.bodySm.copyWith(color: widget.skin.colors.text1, height: 1.4),
                    children: widget.example.highlightedParts
                        .map(
                          (p) => TextSpan(
                            text: p.text,
                            style: p.highlight
                                ? TextStyle(fontWeight: FontWeight.bold, color: widget.skin.colors.accent)
                                : null,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              // 例句发音按钮（音频可用时显示）
              if (widget.example.audioUrl != null && widget.example.audioUrl!.isNotEmpty)
                GestureDetector(
                  onTap: _playExampleAudio,
                  child: Padding(
                    padding: EdgeInsets.only(left: 6, top: 2),
                    child: Icon(Icons.volume_up_outlined, size: 18, color: widget.skin.colors.accent),
                  ),
                ),
              // 收藏按钮
              GestureDetector(
                onTap: _toggleFav,
                child: Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: AnimatedBuilder(
                    animation: _favScaleAnim,
                    builder: (context, child) => Transform.scale(scale: _favScaleAnim.value, child: child),
                    child: Tooltip(
                      message: _isFav ? '取消收藏' : '收藏例句',
                      child: Icon(
                        _isFav ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: _isFav ? widget.skin.colors.danger : widget.skin.colors.text3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (widget.example.cn.isNotEmpty) ...[
            SizedBox(height: 4),
            TextGenerateEffect(
              text: widget.example.cn,
              style: MwTypography.micro.copyWith(color: widget.skin.colors.text3),
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 300),
            ),
          ],
          if (widget.example.source.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(widget.example.source, style: MwTypography.micro.copyWith(color: widget.skin.colors.text3)),
            ),
        ],
      ),
    );
  }
}
