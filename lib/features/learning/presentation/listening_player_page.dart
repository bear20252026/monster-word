// 随身听播放器页面
// 使用系统 TTS 引擎顺序播放单词，支持多种播放模式
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/core/parsers/example_parser.dart';
import 'package:provider/provider.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/core/audio/system_tts.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/features/learning/application/listening_mode.dart';
export 'package:word_app/features/learning/application/listening_mode.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/mw_card.dart';

class ListeningPlayerPage extends StatefulWidget {
  final List<Word> words;
  final int startIndex;
  final ListeningMode mode;
  final String bookName;

  const ListeningPlayerPage({
    super.key,
    required this.words,
    this.startIndex = 0,
    this.mode = ListeningMode.wordOnly,
    this.bookName = '',
  });

  static const routeName = '/listening_player';

  @override
  State<ListeningPlayerPage> createState() => _ListeningPlayerPageState();
}

class _ListeningPlayerPageState extends State<ListeningPlayerPage> with SingleTickerProviderStateMixin {
  late SystemTts _tts;
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _showMeaning = false;
  double _speechRate = 0.5;
  Timer? _autoPlayTimer;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _tts = SystemTts();
    _tts.onComplete = _onSpeechComplete;
    _tts.onErrorHandler = _onSpeechError;
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _progressController.dispose();
    _tts.stop();
    super.dispose();
  }

  Word get _currentWord => widget.words.isNotEmpty
      ? widget.words[_currentIndex]
      : Word(
          id: 0,
          word: '',
          mainWord: '',
          interpret: '',
          ukPron: '',
          usPron: '',
          phrase: '',
          example: '',
          confuse: '',
        );

  void _onSpeechComplete() {
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _showMeaning = true;
    });
  }

  void _onSpeechError() {
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
    });
  }

  Future<void> _speakCurrent() async {
    if (widget.words.isEmpty) return;

    setState(() {
      _isPlaying = true;
      _isPaused = false;
      _showMeaning = false;
    });

    final word = _currentWord;
    switch (widget.mode) {
      case ListeningMode.wordOnly:
        await _tts.speakEnglish(word.word);
        break;
      case ListeningMode.wordMeaning:
        await _tts.speakWordWithMeaning(word.word, word.cleanInterpret);
        break;
      case ListeningMode.meaningWord:
        // 先中文后英文
        await _tts.speakChinese(word.cleanInterpret);
        await Future.delayed(const Duration(milliseconds: 500));
        await _tts.speakEnglish(word.word);
        break;
      case ListeningMode.wordExample:
        await _tts.speakEnglish(word.word);
        if (word.example.isNotEmpty) {
          final sentences = ExampleParser.parse(word.example);
          final firstEn = sentences.isNotEmpty ? sentences.first.en : word.example;
          await Future.delayed(const Duration(milliseconds: 400));
          await _tts.speakEnglish(firstEn);
        }
        break;
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying && !_isPaused) {
      await _tts.pause();
      setState(() => _isPaused = true);
    } else if (_isPaused) {
      // flutter_tts 不支持 resume，重新播放
      await _speakCurrent();
    } else {
      await _speakCurrent();
    }
  }

  Future<void> _next() async {
    if (_currentIndex < widget.words.length - 1) {
      await _tts.stop();
      setState(() {
        _currentIndex++;
        _showMeaning = false;
      });
      if (_isPlaying) {
        await _speakCurrent();
      }
    }
  }

  Future<void> _previous() async {
    if (_currentIndex > 0) {
      await _tts.stop();
      setState(() {
        _currentIndex--;
        _showMeaning = false;
      });
      if (_isPlaying) {
        await _speakCurrent();
      }
    }
  }

  void _onRateChanged(double rate) {
    setState(() => _speechRate = rate);
    _tts.setRate(rate);
  }

  String _modeName(ListeningMode mode) {
    switch (mode) {
      case ListeningMode.wordOnly:
        return '仅单词';
      case ListeningMode.wordMeaning:
        return '单词+释义';
      case ListeningMode.meaningWord:
        return '释义+单词';
      case ListeningMode.wordExample:
        return '单词+例句';
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;

    if (widget.words.isEmpty) {
      return Scaffold(
        backgroundColor: skin.colors.pageBg,
        appBar: AppBar(backgroundColor: skin.colors.pageBg, foregroundColor: skin.colors.text1, elevation: 0),
        body: Center(
          child: Text('暂无单词可播放', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
        ),
      );
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: SafeArea(
          child: Column(
            children: [
              _buildNavBar(skin, resp),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: resp.contentMaxWidth),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: resp.horizontalPadding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 进度指示
                          _buildProgress(skin),
                          const SizedBox(height: 32),
                          // 单词卡片
                          _buildWordCard(skin, resp),
                          const SizedBox(height: 48),
                          // 播放控制
                          _buildControls(skin, resp),
                          const SizedBox(height: 24),
                          // 语速控制
                          _buildRateControl(skin, resp),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin, AppResponsive resp) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => NavUtils.safePop(context),
          ),
          Expanded(
            child: Text(
              '随身听${widget.bookName.isNotEmpty ? " · ${widget.bookName}" : ""}',
              style: MistralTypography.heading5.copyWith(color: skin.colors.text1),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: MistralColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(context.design.radius.sm),
            ),
            child: Text(
              _modeName(widget.mode),
              style: MistralTypography.caption.copyWith(color: MistralColors.primary),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildProgress(SkinSystem skin) {
    final progress = widget.words.isEmpty ? 0.0 : (_currentIndex + 1) / widget.words.length;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${_currentIndex + 1}', style: MistralTypography.heading4.copyWith(color: MistralColors.primary)),
            Text(' / ${widget.words.length}', style: MistralTypography.heading5.copyWith(color: skin.colors.text3)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          width: 200,
          decoration: BoxDecoration(color: skin.colors.divider, borderRadius: BorderRadius.circular(8)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(color: MistralColors.primary, borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordCard(SkinSystem skin, AppResponsive resp) {
    final word = _currentWord;
    final meaningText = word.hasStructuredDefinitions ? word.formattedDefinitions : word.cleanInterpret;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(resp.pageMargin * 1.5),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.xl),
        border: Border.all(color: skin.colors.divider),
      ),
      child: Column(
        children: [
          // 单词
          Text(
            word.word,
            style: AppTypography.heroWord.copyWith(color: skin.colors.text1, fontSize: 48 * resp.fontScale),
            textAlign: TextAlign.center,
          ),
          // 音标
          if (word.usPron.isNotEmpty || word.ukPron.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              word.usPron.isNotEmpty ? word.usPron : word.ukPron,
              style: MistralTypography.body.copyWith(color: skin.colors.text3, fontSize: 16 * resp.fontScale),
              textAlign: TextAlign.center,
            ),
          ],
          // 释义（可显示/隐藏，优先结构化释义）
          if (meaningText.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Text(
                meaningText,
                style: MistralTypography.body.copyWith(
                  color: skin.colors.text2,
                  fontSize: 18 * resp.fontScale,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              crossFadeState: _showMeaning ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
            if (!_showMeaning) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _showMeaning = true),
                child: Text('点击显示释义', style: MistralTypography.caption.copyWith(color: MistralColors.primary)),
              ),
            ],
          ],
          // 例句（结构化）
          if (_showMeaning && word.example.isNotEmpty) ...[
            const SizedBox(height: 16),
            ..._buildStructuredExample(word, skin),
          ],
        ],
      ),
    );
  }

  /// 结构化例句显示
  List<Widget> _buildStructuredExample(Word word, SkinSystem skin) {
    final sentences = ExampleParser.parse(word.example);
    if (sentences.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: skin.colors.cardBgAlt,
            borderRadius: BorderRadius.circular(context.design.radius.md),
          ),
          child: Text(
            word.example,
            style: MistralTypography.bodySm.copyWith(color: skin.colors.text2, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: skin.colors.cardBgAlt,
          borderRadius: BorderRadius.circular(context.design.radius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in sentences) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      s.en,
                      style: MistralTypography.bodySm.copyWith(color: skin.colors.text1, fontStyle: FontStyle.italic),
                    ),
                  ),
                  if (s.audioUrl != null && s.audioUrl!.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.volume_up_outlined, color: skin.colors.accent, size: 18),
                      onPressed: () => context.read<AudioPlaybackState>().playSentence(s.audioUrl!),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minHeight: 24, minWidth: 24),
                    ),
                ],
              ),
              if (s.cn.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(s.cn, style: MistralTypography.caption.copyWith(color: skin.colors.text3)),
                ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _buildControls(SkinSystem skin, AppResponsive resp) {
    final buttonSize = 56.0 * resp.scale;
    return MwCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上一首
          _ControlButton(
            icon: Icons.skip_previous_rounded,
            size: buttonSize,
            onPressed: _currentIndex > 0 ? _previous : null,
            skin: skin,
          ),
          const SizedBox(width: 32),
          // 播放/暂停（主按钮）
          _ControlButton(
            icon: _isPlaying && !_isPaused ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: buttonSize * 1.5,
            onPressed: _togglePlayPause,
            skin: skin,
            isPrimary: true,
          ),
          const SizedBox(width: 32),
          // 下一首
          _ControlButton(
            icon: Icons.skip_next_rounded,
            size: buttonSize,
            onPressed: _currentIndex < widget.words.length - 1 ? _next : null,
            skin: skin,
          ),
        ],
      ),
    );
  }

  Widget _buildRateControl(SkinSystem skin, AppResponsive resp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: skin.colors.cardBgAlt,
        borderRadius: BorderRadius.circular(context.design.radius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed, size: 18, color: skin.colors.text3),
          const SizedBox(width: 8),
          Text('语速', style: MistralTypography.caption.copyWith(color: skin.colors.text3)),
          const SizedBox(width: 12),
          SizedBox(
            width: 140 * resp.scale,
            child: Slider(
              value: _speechRate,
              min: 0.2,
              max: 0.8,
              divisions: 6,
              activeColor: MistralColors.primary,
              inactiveColor: skin.colors.divider,
              onChanged: _onRateChanged,
            ),
          ),
          Text(
            '${(_speechRate * 2).toStringAsFixed(1)}x',
            style: MistralTypography.caption.copyWith(color: skin.colors.text2),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onPressed;
  final SkinSystem skin;
  final bool isPrimary;

  const _ControlButton({
    required this.icon,
    required this.size,
    this.onPressed,
    required this.skin,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? MistralColors.primary : skin.colors.cardBgAlt,
      borderRadius: BorderRadius.circular(size / 2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.5,
            color: isPrimary
                ? Colors.white
                : (onPressed != null ? skin.colors.text1 : skin.colors.text3.withValues(alpha: 0.3)),
          ),
        ),
      ),
    );
  }
}
