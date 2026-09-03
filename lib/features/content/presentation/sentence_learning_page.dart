// 句库翻卡学习器：看句猜词 → 翻卡看答案 → 认识/不认识，不认识的句子回到队尾循环
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:word_app/core/audio/audio_service.dart';
import 'package:word_app/models/sentence_models.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';

/// 单句学习项。
class _LearningItem {
  _LearningItem(this.fav);
  final FavSentenceData fav;
  bool mastered = false;
}

class SentenceLearningPage extends StatefulWidget {
  const SentenceLearningPage({super.key, required this.sentences});

  final List<FavSentenceData> sentences;

  @override
  State<SentenceLearningPage> createState() => _SentenceLearningPageState();
}

class _SentenceLearningPageState extends State<SentenceLearningPage> {
  late final List<_LearningItem> _all;
  late List<int> _queue; // 待学习项在 _all 中的下标
  int _masteredCount = 0;
  bool _revealed = false;

  AudioService get _audio => GetIt.I<AudioService>();

  @override
  void initState() {
    super.initState();
    _all = widget.sentences.where((s) => (s.sentenceData?.e ?? '').isNotEmpty).map(_LearningItem.new).toList();
    _queue = List.generate(_all.length, (i) => i);
  }

  int get _total => _all.length;

  bool get _finished => _queue.isEmpty;

  void _markMastered() {
    final item = _all[_queue.first];
    setState(() {
      item.mastered = true;
      _queue.removeAt(0);
      _masteredCount++;
      _revealed = false;
    });
  }

  void _markAgain() {
    // 不认识：移到队尾循环，直到掌握
    setState(() {
      final head = _queue.removeAt(0);
      _queue.add(head);
      _revealed = false;
    });
  }

  void _restart() {
    setState(() {
      for (final item in _all) {
        item.mastered = false;
      }
      _queue = List.generate(_all.length, (i) => i);
      _masteredCount = 0;
      _revealed = false;
    });
  }

  void _playAudio(FavSentenceData fav) {
    final url = fav.sentenceData?.u ?? '';
    if (url.isNotEmpty) {
      _audio.playFromUrl(url);
    } else {
      _audio.playWordAudio(fav.word);
    }
  }

  /// 把目标单词从例句中挖空为 ____（大小写不敏感）。
  String _maskedSentence(FavSentenceData fav) {
    final text = fav.sentenceData?.e ?? '';
    final word = fav.word.trim();
    if (word.isEmpty) return text;
    final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
    return text.replaceAllMapped(pattern, (_) => '____');
  }

  /// 高亮答案句中的目标单词。
  List<TextSpan> _highlightedSentence(FavSentenceData fav, Color highlight) {
    final text = fav.sentenceData?.e ?? '';
    final word = fav.word.trim();
    if (word.isEmpty) return [TextSpan(text: text)];
    final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
    return text
        .splitMapJoin(pattern, onMatch: (m) => '\u0000${m[0]}\u0000', onNonMatch: (t) => t)
        .split('\u0000')
        .indexed
        .map((e) {
          final isMatch = e.$1.isOdd;
          return TextSpan(
            text: e.$2,
            style: isMatch ? TextStyle(color: highlight, fontWeight: FontWeight.w700) : null,
          );
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: _finished
            ? _buildCompleteView(skin)
            : Column(
                children: [
                  _buildNavBar(skin),
                  _buildProgressBar(skin),
                  Expanded(child: _buildCardArea(skin)),
                ],
              ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('句库学习', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text('$_masteredCount/$_total', style: MwTypography.bodySm.copyWith(color: skin.colors.text2)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(SkinSystem skin) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.design.radius.pill),
        child: LinearProgressIndicator(
          value: _total == 0 ? 0 : _masteredCount / _total,
          minHeight: 4,
          backgroundColor: skin.colors.divider,
          color: MwColors.primary,
        ),
      ),
    );
  }

  Widget _buildCardArea(SkinSystem skin) {
    final fav = _all[_queue.first].fav;
    final data = fav.sentenceData!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            // ScaleDownOnPress（v2.7.50）：翻转闪卡加按压反馈，与全 App 交互统一
            child: ScaleDownOnPress(
              onTap: () {
                if (!_revealed) setState(() => _revealed = true);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: skin.colors.cardBgAlt,
                  borderRadius: BorderRadius.circular(context.design.radius.lg),
                  border: Border.all(color: skin.colors.divider),
                ),
                child: _revealed ? _buildCardBack(fav, data, skin) : _buildCardFront(fav, data, skin),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButtons(skin),
        ],
      ),
    );
  }

  Widget _buildCardFront(FavSentenceData fav, SentenceData data, SkinSystem skin) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('想想缺失的单词', style: MwTypography.bodySm.copyWith(color: skin.colors.text3)),
        const SizedBox(height: 16),
        Text(_maskedSentence(fav), style: MwTypography.heading4.copyWith(color: skin.colors.text1, height: 1.6)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (data.b.isNotEmpty) ...[
              Icon(Icons.menu_book, size: 14, color: skin.colors.text3),
              const SizedBox(width: 4),
              Flexible(
                child: Text('— ${data.b}', style: MwTypography.micro.copyWith(color: skin.colors.text3)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        Text('点击卡片查看答案', style: MwTypography.bodySm.copyWith(color: MwColors.primary)),
      ],
    );
  }

  Widget _buildCardBack(FavSentenceData fav, SentenceData data, SkinSystem skin) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: MwColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(context.design.radius.pill),
              ),
              child: Text(
                fav.word,
                style: MwTypography.body.copyWith(color: MwColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: IconButton(
              icon: const Icon(Icons.volume_up),
              color: MwColors.primary,
              onPressed: () => _playAudio(fav),
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(children: _highlightedSentence(fav, MwColors.primary)),
            style: MwTypography.heading4.copyWith(color: skin.colors.text1, height: 1.6),
          ),
          if (data.c.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(data.c, style: MwTypography.body.copyWith(color: skin.colors.text2)),
          ],
          if (data.b.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('— ${data.b}', style: MwTypography.micro.copyWith(color: skin.colors.text3)),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(SkinSystem skin) {
    if (!_revealed) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: () => setState(() => _revealed = true),
          style: ElevatedButton.styleFrom(
            backgroundColor: MwColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
          ),
          child: const Text('显示答案'),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _markAgain,
              style: OutlinedButton.styleFrom(
                foregroundColor: MwColors.warning,
                side: const BorderSide(color: MwColors.warning),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
              ),
              child: const Text('不认识'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _markMastered,
              style: ElevatedButton.styleFrom(
                backgroundColor: MwColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
              ),
              child: const Text('认识'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteView(SkinSystem skin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, size: 72, color: MwColors.primary),
          const SizedBox(height: 16),
          Text('全部掌握！', style: MwTypography.heading3.copyWith(color: skin.colors.text1)),
          const SizedBox(height: 8),
          Text('共 $_total 个例句都学会了', style: MwTypography.body.copyWith(color: skin.colors.text2)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _restart,
                style: OutlinedButton.styleFrom(
                  foregroundColor: MwColors.primary,
                  side: const BorderSide(color: MwColors.primary),
                ),
                child: const Text('再学一轮'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: MwColors.primary, foregroundColor: Colors.white),
                child: const Text('完成'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 句库学习入口：从 my_fav_sentence「开始学习」进入。
Future<void> startSentenceLearning(BuildContext context, List<FavSentenceData> sentences) {
  return Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SentenceLearningPage(sentences: sentences)));
}
