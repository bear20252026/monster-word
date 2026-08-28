// 随手拼页面
// 看中文释义快速拼写单词，限时挑战模式
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// wordbook_database.dart removed - not used in this file
import '../core/audio/audio_playback_state.dart';
import '../core/router/nav_utils.dart';
import '../data/example_parser.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../hooks/responsive.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class QuickSpellPage extends StatefulWidget {
  final List<Word> words;
  final String bookName;

  const QuickSpellPage({super.key, required this.words, this.bookName = ''});

  static const routeName = '/quick_spell';

  @override
  State<QuickSpellPage> createState() => _QuickSpellPageState();
}

class _QuickSpellPageState extends State<QuickSpellPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late List<Word> _shuffledWords;
  int _currentIndex = 0;
  bool _answered = false;
  bool _isCorrect = false;
  int _correctCount = 0;
  int _totalAttempted = 0;
  bool _completed = false;

  // 限时模式
  bool _timedMode = false;
  final int _timeLimit = 60; // 秒
  int _remaining = 60;
  Timer? _countdownTimer;
  Timer? _autoNextTimer;

  @override
  void initState() {
    super.initState();
    _shuffledWords = List.from(widget.words)..shuffle(Random());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _autoNextTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Word get _currentWord => _shuffledWords.isNotEmpty
      ? _shuffledWords[_currentIndex]
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

  void _checkAnswer() {
    if (_answered || _shuffledWords.isEmpty) return;

    final input = _controller.text.trim().toLowerCase();
    final correct = _currentWord.word.toLowerCase();

    setState(() {
      _answered = true;
      _isCorrect = input == correct;
      _totalAttempted++;
      if (_isCorrect) _correctCount++;
    });

    _autoNextTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _next();
    });
  }

  void _next() {
    _autoNextTimer?.cancel();
    if (_currentIndex < _shuffledWords.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _isCorrect = false;
        _controller.clear();
      });
      _focusNode.requestFocus();
    } else {
      setState(() => _completed = true);
      _countdownTimer?.cancel();
    }
  }

  void _skip() {
    if (!_answered) {
      setState(() {
        _answered = true;
        _isCorrect = false;
        _totalAttempted++;
      });
      _autoNextTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) _next();
      });
    } else {
      _next();
    }
  }

  void _startTimedMode() {
    setState(() {
      _timedMode = true;
      _remaining = _timeLimit;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _completed = true);
        }
      } else if (mounted) {
        setState(() => _remaining--);
      }
    });
  }

  void _restart() {
    _countdownTimer?.cancel();
    setState(() {
      _shuffledWords = List.from(widget.words)..shuffle(Random());
      _currentIndex = 0;
      _answered = false;
      _isCorrect = false;
      _correctCount = 0;
      _totalAttempted = 0;
      _completed = false;
      _controller.clear();
      _remaining = _timeLimit;
    });
    if (_timedMode) {
      _startTimedMode();
    }
    _focusNode.requestFocus();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;

    if (widget.words.isEmpty) {
      return Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard, size: 64, color: skin.colors.text3),
              const SizedBox(height: 16),
              Text('暂无可拼写单词', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
              const SizedBox(height: 8),
              Text('该词书暂无合适的学习内容', style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => NavUtils.goHome(context),
                icon: const Icon(Icons.home, size: 20),
                label: const Text('返回首页'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: skin.colors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_completed) {
      return _buildResultPage(skin, resp);
    }

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: resp.contentMaxWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: resp.horizontalPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildProgressAndTimer(skin),
                        const SizedBox(height: 32),
                        _buildMeaningCard(skin, resp),
                        const SizedBox(height: 32),
                        _buildInput(skin, resp),
                        const SizedBox(height: 24),
                        _buildFeedback(skin),
                        const SizedBox(height: 24),
                        _buildActionButtons(skin),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 24),
            color: skin.colors.text1,
            onPressed: () {
              _countdownTimer?.cancel();
              NavUtils.safePop(context);
            },
          ),
          Expanded(
            child: Text(
              '随手拼${widget.bookName.isNotEmpty ? " · ${widget.bookName}" : ""}',
              style: MistralTypography.heading5.copyWith(color: skin.colors.text1),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!_timedMode)
            TextButton(
              onPressed: _startTimedMode,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, size: 18, color: MistralColors.primary),
                  const SizedBox(width: 4),
                  Text('限时', style: TextStyle(color: MistralColors.primary)),
                ],
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildProgressAndTimer(SkinSystem skin) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${_currentIndex + 1}', style: MistralTypography.heading4.copyWith(color: MistralColors.primary)),
            Text(' / ${_shuffledWords.length}', style: MistralTypography.heading5.copyWith(color: skin.colors.text3)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_timedMode) ...[
              Icon(Icons.timer, size: 16, color: _remaining <= 10 ? MistralColors.error : skin.colors.text3),
              const SizedBox(width: 4),
              Text(
                _formatTime(_remaining),
                style: MistralTypography.body.copyWith(
                  color: _remaining <= 10 ? MistralColors.error : skin.colors.text2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 24),
            ],
            Icon(Icons.check_circle, size: 16, color: MistralColors.success),
            const SizedBox(width: 4),
            Text('$_correctCount', style: MistralTypography.body.copyWith(color: MistralColors.success)),
            const SizedBox(width: 16),
            Icon(Icons.cancel, size: 16, color: MistralColors.error),
            const SizedBox(width: 4),
            Text(
              '${_totalAttempted - _correctCount}',
              style: MistralTypography.body.copyWith(color: MistralColors.error),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMeaningCard(SkinSystem skin, AppResponsive resp) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: 500 * resp.scale),
      padding: EdgeInsets.all(resp.pageMargin * 1.5),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: skin.colors.divider),
      ),
      child: Column(
        children: [
          Text(
            _currentWord.hasStructuredDefinitions ? _currentWord.formattedDefinitions : _currentWord.cleanInterpret,
            style: MistralTypography.heading4.copyWith(
              color: skin.colors.text1,
              fontSize: 24 * resp.fontScale,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (_currentWord.example.isNotEmpty && _answered) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: skin.colors.cardBgAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: ExampleParser.parse(_currentWord.example).take(2).map((ex) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: ex.cleanEn, style: MistralTypography.bodySm.copyWith(
                                    color: skin.colors.text2,
                                    fontStyle: FontStyle.italic,
                                    height: 1.4,
                                  )),
                                  if (ex.cn.isNotEmpty) TextSpan(text: '\n${ex.cn}', style: MistralTypography.caption.copyWith(
                                    color: skin.colors.text3,
                                    height: 1.4,
                                  )),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (ex.audioUrl != null && ex.audioUrl!.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.volume_up_outlined, color: skin.colors.accent, size: 18),
                              onPressed: () => context.read<AudioPlaybackState>().playSentence(ex.audioUrl!),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minHeight: 24, minWidth: 24),
                            ),
                        ],
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInput(SkinSystem skin, AppResponsive resp) {
    return Container(
      constraints: BoxConstraints(maxWidth: 400 * resp.scale),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: !_answered,
        autofocus: true,
        textAlign: TextAlign.center,
        style: MistralTypography.heading4.copyWith(
          color: skin.colors.text1,
          fontSize: 28 * resp.fontScale,
          letterSpacing: 2,
        ),
        decoration: InputDecoration(
          hintText: '输入英文单词',
          hintStyle: MistralTypography.body.copyWith(color: skin.colors.text3),
          filled: true,
          fillColor: skin.colors.cardBgAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide(color: skin.colors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide(color: skin.colors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide(color: MistralColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onSubmitted: (_) => _checkAnswer(),
      ),
    );
  }

  Widget _buildFeedback(SkinSystem skin) {
    if (!_answered) return const SizedBox(height: 24);

    return AnimatedOpacity(
      opacity: _answered ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: _isCorrect
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: MistralColors.success, size: 28),
                const SizedBox(width: 8),
                Text('正确！', style: MistralTypography.bodyBold.copyWith(color: MistralColors.success)),
              ],
            )
          : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.close, color: MistralColors.error, size: 28),
                    const SizedBox(width: 8),
                    Text('错误', style: MistralTypography.bodyBold.copyWith(color: MistralColors.error)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_currentWord.word, style: MistralTypography.heading4.copyWith(color: MistralColors.primary)),
              ],
            ),
    );
  }

  Widget _buildActionButtons(SkinSystem skin) {
    if (_answered) return const SizedBox(height: 48);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: _skip,
          style: OutlinedButton.styleFrom(
            foregroundColor: skin.colors.text2,
            side: BorderSide(color: skin.colors.divider),
            minimumSize: const Size(100, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          ),
          child: const Text('跳过'),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _controller.text.trim().isNotEmpty ? _checkAnswer : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: MistralColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(120, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          ),
          child: const Text('确认'),
        ),
      ],
    );
  }

  Widget _buildResultPage(SkinSystem skin, AppResponsive resp) {
    final accuracy = _totalAttempted > 0 ? (_correctCount / _totalAttempted * 100).round() : 0;
    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: resp.contentMaxWidth),
            child: Padding(
              padding: EdgeInsets.all(resp.pageMargin * 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    accuracy >= 80 ? Icons.emoji_events : Icons.thumb_up,
                    color: accuracy >= 80 ? MistralColors.accent : MistralColors.primary,
                    size: 80 * resp.scale,
                  ),
                  const SizedBox(height: 24),
                  Text('挑战完成！', style: MistralTypography.heading3.copyWith(color: skin.colors.text1)),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: skin.colors.cardBg,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: skin.colors.divider),
                    ),
                    child: Column(
                      children: [
                        _resultRow('完成', '$_totalAttempted 题', skin),
                        const SizedBox(height: 12),
                        _resultRow('答对', '$_correctCount', skin, valueColor: MistralColors.success),
                        const SizedBox(height: 12),
                        _resultRow('正确率', '$accuracy%', skin, valueColor: MistralColors.primary),
                        if (_timedMode) ...[
                          const SizedBox(height: 12),
                          _resultRow('用时', '${_timeLimit - _remaining}秒', skin),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _restart,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: skin.colors.text2,
                          side: BorderSide(color: skin.colors.divider),
                          minimumSize: const Size(120, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                        ),
                        child: const Text('再来一次'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () => NavUtils.goHome(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MistralColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(120, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                        ),
                        child: const Text('返回'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, SkinSystem skin, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: MistralTypography.body.copyWith(color: skin.colors.text2)),
        Text(value, style: MistralTypography.heading5.copyWith(color: valueColor ?? skin.colors.text1)),
      ],
    );
  }
}
