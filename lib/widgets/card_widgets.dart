// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 学习卡片控件：翻译自 widget/card/ 子包
// 文件：InterpretContainer, LearnCardViewDragHelper, PhoneticView, SentenceCardView,
//       ViewRecycleHelper, WordPairContainerView, WordRootCardView, WordSimpleAcceptionWindow

import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import 'animations.dart';
import 'learn_widgets.dart';

/// 音标视图（翻译自 PhoneticView.dart）
class PhoneticText extends StatelessWidget {
  final String phonetic;
  final TextStyle? style;
  final bool isAmerican;

  const PhoneticText({super.key, required this.phonetic, this.style, this.isAmerican = true});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Text(
      phonetic,
      style:
          style ??
          TextStyle(
            fontSize: 14,
            color: skin.text2,
            // 音标字体：原 'phonetic' family 未在 pubspec 注册，Charter 又缺 ŋ/ˈ/ˌ/ː 等 IPA 字符，
            // 故不指定 fontFamily，回退主题默认字体（Inter 对 IPA 覆盖完整）。
          ),
    );
  }
}

/// 释义容器（翻译自 InterpretContainer.dart）
class InterpretationContainer extends StatelessWidget {
  final List<InterpretationItem> items;
  final TextStyle? titleStyle;
  final TextStyle? contentStyle;

  const InterpretationContainer({super.key, required this.items, this.titleStyle, this.contentStyle});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.pos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 8, top: 2),
                  decoration: BoxDecoration(
                    color: skin.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(item.pos, style: titleStyle ?? TextStyle(fontSize: 12, color: skin.accent)),
                ),
              Expanded(
                child: Text(item.meaning, style: contentStyle ?? TextStyle(fontSize: 14, color: skin.text1)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class InterpretationItem {
  final String pos; // 词性
  final String meaning; // 释义

  const InterpretationItem({this.pos = '', required this.meaning});
}

/// 例句卡片（翻译自 SentenceCardView.dart）
class SentenceCard extends StatelessWidget {
  final String english;
  final String chinese;
  final String? audioUrl;
  final VoidCallback? onPlayAudio;
  final ValueChanged<String>? onWordTap;

  const SentenceCard({
    super.key,
    required this.english,
    required this.chinese,
    this.audioUrl,
    this.onPlayAudio,
    this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: skin.text1.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 英文例句
          GestureDetector(
            onTapUp: (details) {
              // 简化的单词点击检测
              final text = english;
              onWordTap?.call(text);
            },
            child: Text(english, style: const TextStyle(fontSize: 16, height: 1.5)),
          ),
          const SizedBox(height: 8),
          // 中文翻译
          Text(chinese, style: TextStyle(fontSize: 14, color: skin.text2, height: 1.5)),
          // 播放按钮
          if (audioUrl != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onPlayAudio,
              child: Icon(Icons.volume_up, color: skin.accent, size: 24),
            ),
          ],
        ],
      ),
    );
  }
}

/// 词根卡片（翻译自 WordRootCardView.dart）
class WordRootCard extends StatelessWidget {
  final String root;
  final String meaning;
  final List<String> examples;

  const WordRootCard({super.key, required this.root, required this.meaning, required this.examples});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: skin.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  root,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: skin.accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(meaning, style: TextStyle(fontSize: 14, color: skin.text1)),
              ),
            ],
          ),
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...examples.map(
              (ex) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $ex', style: TextStyle(fontSize: 13, color: skin.text2)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 单词配对容器（翻译自 WordPairContainerView.dart）
class WordPairContainer extends StatelessWidget {
  final List<WordPair> pairs;
  final ValueChanged<int>? onPairSelected;

  const WordPairContainer({super.key, required this.pairs, this.onPairSelected});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(pairs.length, (index) {
        final pair = pairs[index];
        return GestureDetector(
          onTap: () => onPairSelected?.call(index),
          child: Chip(
            label: Text(pair.word),
            avatar: pair.selected ? const Icon(Icons.check, size: 18) : null,
            backgroundColor: skin.cardBgAlt,
          ),
        );
      }),
    );
  }
}

class WordPair {
  final String word;
  final String meaning;
  final bool selected;

  const WordPair({required this.word, required this.meaning, this.selected = false});
}

/// 单词简义弹窗（翻译自 WordSimpleAcceptionWindow.dart）
class WordSimplePopup extends StatelessWidget {
  final String word;
  final String phonetic;
  final List<String> meanings;
  final VoidCallback? onClose;

  const WordSimplePopup({super.key, required this.word, required this.phonetic, required this.meanings, this.onClose});

  /// 显示单词简义弹窗
  static void show(
    BuildContext context, {
    required String word,
    required String phonetic,
    required List<String> meanings,
    required Offset position,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: position.dx.clamp(16, MediaQuery.of(context).size.width - 250),
        top: position.dy + 20,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: WordSimplePopup(word: word, phonetic: phonetic, meanings: meanings, onClose: () => entry.remove()),
        ),
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: skin.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(word, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close, size: 18, color: skin.text3),
              ),
            ],
          ),
          if (phonetic.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(phonetic, style: TextStyle(fontSize: 13, color: skin.text3)),
          ],
          const SizedBox(height: 8),
          ...meanings
              .take(3)
              .map(
                (m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    m,
                    style: TextStyle(fontSize: 13, color: skin.text1),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// 卡片拖拽辅助（翻译自 LearnCardViewDragHelper.dart）
/// Flutter 中使用 GestureDetector + AnimationController 实现
class CardDragHelper {
  final TickerProvider vsync;
  late AnimationController _controller;
  double _offset = 0;
  final double slideRange;
  final VoidCallback? onPositionChanged;
  final ValueChanged<LearnPanelState>? onStateChanged;

  CardDragHelper({required this.vsync, required this.slideRange, this.onPositionChanged, this.onStateChanged}) {
    _controller = AnimationController(vsync: vsync);
  }

  void dispose() {
    _controller.dispose();
  }

  void dragTo(double delta) {
    _offset = (_offset + delta).clamp(-slideRange, 0);
    onPositionChanged?.call();
  }

  void smoothSlideTo(double target) {
    final anim = Tween<double>(
      begin: _offset,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: const SpringCurve()));
    _controller.forward(from: 0);
    anim.addListener(() {
      _offset = anim.value;
      onPositionChanged?.call();
    });
  }

  double get currentOffset => _offset;
  double get slideFraction => (_offset / slideRange).abs();
}
