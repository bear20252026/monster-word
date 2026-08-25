// 听写练习页面
// 系统 TTS 播放单词发音，用户输入拼写，实时判分
import 'dart:async';
import 'package:flutter/material.dart';

import '../data/wordbook_database.dart';
import '../hooks/responsive.dart';
import '../player/system_tts.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class DictationSessionPage extends StatefulWidget {
  final List<Word> words;
  final String bookName;

  const DictationSessionPage({
    super.key,
    required this.words,
    this.bookName = '',
  });

  static const routeName = '/dictation_session';

  @override
  State<DictationSessionPage> createState() => _DictationSessionPageState();
}

class _DictationSessionPageState extends State<DictationSessionPage> {
  late SystemTts _tts;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  int _currentIndex = 0;
  bool _answered = false;
  bool _isCorrect = false;
  int _correctCount = 0;
  int _totalAttempted = 0;
  bool _completed = false;
  Timer? _autoNextTimer;

  @override
  void initState() {
    super.initState();
    _tts = SystemTts();
    _tts.onComplete = () {};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakWord();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _tts.stop();
    super.dispose();
  }

  Word get _currentWord =>
      widget.words.isNotEmpty ? widget.words[_currentIndex] : Word(
        id: 0, word: '', mainWord: '', interpret: '', ukPron: '', usPron: '',
        phrase: '', example: '', confuse: '',
      );

  Future<void> _speakWord() async {
    if (widget.words.isEmpty) return;
    await _tts.speakEnglish(_currentWord.word);
  }

  void _checkAnswer() {
    if (_answered || widget.words.isEmpty) return;

    final input = _controller.text.trim().toLowerCase();
    final correct = _currentWord.word.toLowerCase();

    setState(() {
      _answered = true;
      _isCorrect = input == correct;
      _totalAttempted++;
      if (_isCorrect) _correctCount++;
    });

    // 2秒后自动下一题
    _autoNextTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _next();
    });
  }

  void _next() {
    _autoNextTimer?.cancel();
    if (_currentIndex < widget.words.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _isCorrect = false;
        _controller.clear();
      });
      _speakWord();
      _focusNode.requestFocus();
    } else {
      setState(() => _completed = true);
    }
  }

  void _skip() {
    if (_answered) {
      _next();
    } else {
      setState(() {
        _answered = true;
        _isCorrect = false;
        _totalAttempted++;
      });
    }
  }

  void _restart() {
    setState(() {
      _currentIndex = 0;
      _answered = false;
      _isCorrect = false;
      _correctCount = 0;
      _totalAttempted = 0;
      _completed = false;
      _controller.clear();
    });
    _speakWord();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;

    if (widget.words.isEmpty) {
      return Scaffold(
        backgroundColor: skin.colors.pageBg,
        appBar: AppBar(backgroundColor: skin.colors.pageBg, elevation: 0),
        body: Center(child: Text('暂无单词', style: MistralTypography.body.copyWith(color: skin.colors.text3))),
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
                        _buildProgress(skin),
                        const SizedBox(height: 40),
                        _buildPlayButton(skin, resp),
                        const SizedBox(height: 16),
                        Text(
                          _currentWord.hasStructuredDefinitions
                              ? _currentWord.formattedDefinitions
                              : _currentWord.cleanInterpret,
                          style: MistralTypography.body.copyWith(
                            color: skin.colors.text2,
                            fontSize: 18 * resp.fontScale,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        _buildInput(skin, resp),
                        const SizedBox(height: 24),
                        _buildFeedback(skin),
                        const SizedBox(height: 32),
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
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              '听写练习${widget.bookName.isNotEmpty ? " · ${widget.bookName}" : ""}',
              style: MistralTypography.heading5.copyWith(color: skin.colors.text1),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${_currentIndex + 1}/${widget.words.length}',
            style: MistralTypography.body.copyWith(color: skin.colors.text3),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildProgress(SkinSystem skin) {
    final progress = (_currentIndex + 1) / widget.words.length;
    return Container(
      height: 6,
      width: double.infinity,
      decoration: BoxDecoration(
        color: skin.colors.divider,
        borderRadius: BorderRadius.circular(8),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: MistralColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(SkinSystem skin, AppResponsive resp) {
    return Material(
      color: MistralColors.primary,
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        onTap: _speakWord,
        borderRadius: BorderRadius.circular(40),
        child: SizedBox(
          width: 80 * resp.scale,
          height: 80 * resp.scale,
          child: const Icon(Icons.volume_up, color: Colors.white, size: 40),
        ),
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
          hintText: '输入你听到的单词',
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: MistralColors.error, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onSubmitted: (_) => _checkAnswer(),
      ),
    );
  }

  Widget _buildFeedback(SkinSystem skin) {
    if (!_answered) return const SizedBox(height: 48);

    if (_isCorrect) {
      return Column(
        children: [
          const Icon(Icons.check_circle, color: MistralColors.success, size: 48),
          const SizedBox(height: 8),
          Text('正确！', style: MistralTypography.heading5.copyWith(color: MistralColors.success)),
        ],
      );
    } else {
      return Column(
        children: [
          const Icon(Icons.cancel, color: MistralColors.error, size: 48),
          const SizedBox(height: 8),
          Text('正确答案：', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
          Text(
            _currentWord.word,
            style: MistralTypography.heading4.copyWith(color: MistralColors.primary),
          ),
        ],
      );
    }
  }

  Widget _buildActionButtons(SkinSystem skin) {
    if (_answered) {
      return ElevatedButton(
        onPressed: _next,
        style: ElevatedButton.styleFrom(
          backgroundColor: MistralColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(160, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        ),
        child: Text(_currentIndex < widget.words.length - 1 ? '下一题' : '完成'),
      );
    }

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
                  Text('听写完成！', style: MistralTypography.heading3.copyWith(color: skin.colors.text1)),
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
                        _resultRow('总题数', '${widget.words.length}', skin),
                        const SizedBox(height: 12),
                        _resultRow('答对', '$_correctCount', skin, valueColor: MistralColors.success),
                        const SizedBox(height: 12),
                        _resultRow('正确率', '$accuracy%', skin, valueColor: MistralColors.primary),
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
                        onPressed: () => Navigator.pop(context),
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
