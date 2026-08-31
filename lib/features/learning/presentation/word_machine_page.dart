// 由 Claude 团队生成 | Monster Word App

// 单词机：单词卡片机样式展示，支持滑动浏览
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/core/router/nav_utils.dart';
import 'package:word_app/core/parsers/example_parser.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';

class WordMachinePage extends StatefulWidget {
  const WordMachinePage({super.key});

  static const routeName = '/word_machine';

  @override
  State<WordMachinePage> createState() => _WordMachinePageState();
}

class _WordMachinePageState extends State<WordMachinePage> {
  List<Word> _words = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _showMeaning = false;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      final session = context.read<LearningSessionState>();
      final words = session.queue.toList();
      if (!mounted) return;
      setState(() {
        _words = words;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Word get _currentWord => _words.isNotEmpty
      ? _words[_currentIndex]
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

  void _next() {
    if (_currentIndex < _words.length - 1) {
      setState(() {
        _currentIndex++;
        _showMeaning = false;
      });
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showMeaning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;

    if (_loading) {
      return Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_words.isEmpty) {
      return Scaffold(
        backgroundColor: skin.colors.pageBg,
        appBar: AppBar(backgroundColor: skin.colors.pageBg, foregroundColor: skin.colors.text1, elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: skin.colors.text3),
              const SizedBox(height: 16),
              Text('暂无待学习单词', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin, resp),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: resp.contentMaxWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: resp.horizontalPadding),
                    child: _buildPlayView(skin, resp),
                  ),
                ),
              ),
            ),
          ],
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
          const SizedBox(width: 4),
          Text('单词机', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: MistralColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(context.design.radius.pill),
            ),
            child: Text(
              '${_currentIndex + 1} / ${_words.length}',
              style: MistralTypography.bodyBold.copyWith(color: MistralColors.primary),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildPlayView(SkinSystem skin, AppResponsive resp) {
    final word = _currentWord;
    final meaningText = word.hasStructuredDefinitions ? word.formattedDefinitions : word.cleanInterpret;
    final sentences = ExampleParser.parse(word.example);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 单词卡片
        Container(
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
              // 释义（可显示/隐藏）
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
              // 例句
              if (_showMeaning && sentences.isNotEmpty) ...[
                const SizedBox(height: 16),
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
                                style: MistralTypography.bodySm.copyWith(
                                  color: skin.colors.text1,
                                  fontStyle: FontStyle.italic,
                                ),
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
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        // 控制按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlButton(icon: Icons.arrow_back_rounded, onPressed: _currentIndex > 0 ? _previous : null, skin: skin),
            const SizedBox(width: 24),
            _ControlButton(
              icon: Icons.volume_up_rounded,
              onPressed: () => context.read<AudioPlaybackState>().playWord(word.word),
              skin: skin,
              isPrimary: true,
            ),
            const SizedBox(width: 24),
            _ControlButton(
              icon: Icons.arrow_forward_rounded,
              onPressed: _currentIndex < _words.length - 1 ? _next : null,
              skin: skin,
            ),
          ],
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final SkinSystem skin;
  final bool isPrimary;

  const _ControlButton({required this.icon, this.onPressed, required this.skin, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    final size = isPrimary ? 56.0 : 44.0;
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
