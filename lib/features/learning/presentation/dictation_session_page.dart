// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 DictationSessionActivity
// 单词听写会话：播放语音 → 用户拼写 → 即时反馈
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/audio_playback_state.dart';
import '../../../core/router/nav_utils.dart';
import '../../../hooks/responsive.dart';
import '../../../models/word.dart';
import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';
import 'learning_session_state.dart';

class DictationSessionPage extends StatefulWidget {
  const DictationSessionPage({super.key});

  static const routeName = '/dictation_session';

  @override
  State<DictationSessionPage> createState() => _DictationSessionPageState();
}

class _DictationSessionPageState extends State<DictationSessionPage> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();

  List<Word> _words = [];
  int _currentIndex = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  bool _loading = true;
  bool _showAnswer = false;
  bool _finished = false;
  String _feedback = '';

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
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
      if (words.isNotEmpty) {
        _focusNode.requestFocus();
      }
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

  void _checkAnswer() {
    if (_showAnswer || _finished) return;
    final input = _inputController.text.trim().toLowerCase();
    final correct = _currentWord.word.toLowerCase();
    setState(() {
      _showAnswer = true;
      if (input == correct) {
        _correctCount++;
        _feedback = '✓ 正确！';
      } else {
        _wrongCount++;
        _feedback = '✗ 正确答案：${_currentWord.word}';
      }
    });
  }

  void _nextWord() {
    if (_finished) return;
    if (_currentIndex >= _words.length - 1) {
      setState(() => _finished = true);
      _showResultDialog();
      return;
    }
    setState(() {
      _currentIndex++;
      _showAnswer = false;
      _feedback = '';
      _inputController.clear();
    });
    _focusNode.requestFocus();
  }

  void _showResultDialog() {
    final accuracy = _correctCount + _wrongCount > 0
        ? (_correctCount / (_correctCount + _wrongCount) * 100).toStringAsFixed(1)
        : '0';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.skin.colors.cardBg,
        title: Text('听写完成', style: MistralTypography.heading4.copyWith(color: context.skin.colors.text1)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('正确：$_correctCount', style: MistralTypography.body.copyWith(color: MistralColors.success)),
            Text('错误：$_wrongCount', style: MistralTypography.body.copyWith(color: MistralColors.danger)),
            const SizedBox(height: 8),
            Text('正确率：$accuracy%', style: MistralTypography.bodyBold.copyWith(color: context.skin.colors.text1)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              NavUtils.safePop(context);
            },
            child: const Text('返回'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetSession();
            },
            style: ElevatedButton.styleFrom(backgroundColor: MistralColors.primary, foregroundColor: Colors.white),
            child: const Text('再来一次'),
          ),
        ],
      ),
    );
  }

  void _resetSession() {
    setState(() {
      _currentIndex = 0;
      _correctCount = 0;
      _wrongCount = 0;
      _showAnswer = false;
      _finished = false;
      _feedback = '';
      _inputController.clear();
    });
    _loadWords();
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
              Icon(Icons.record_voice_over, size: 64, color: skin.colors.text3),
              const SizedBox(height: 16),
              Text('暂无待学习单词', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => NavUtils.goHome(context),
                icon: const Icon(Icons.home_outlined, size: 18),
                label: const Text('返回首页'),
                style: TextButton.styleFrom(foregroundColor: skin.colors.text1),
              ),
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
          Text('单词听写', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 播放按钮
        GestureDetector(
          onTap: () => context.read<AudioPlaybackState>().playWord(_currentWord.word),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MistralColors.cream,
              border: Border.all(color: MistralColors.primary, width: 2),
            ),
            child: Icon(Icons.volume_up, size: 40, color: MistralColors.primary),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.read<AudioPlaybackState>().playWord(_currentWord.word),
          child: Text('点击播放', style: TextStyle(color: MistralColors.primary)),
        ),
        const SizedBox(height: 32),
        // 输入框
        TextField(
          controller: _inputController,
          focusNode: _focusNode,
          enabled: !_showAnswer,
          textAlign: TextAlign.center,
          style: MistralTypography.heading3.copyWith(color: skin.colors.text1),
          decoration: InputDecoration(
            hintText: '请输入单词',
            hintStyle: MistralTypography.body.copyWith(color: skin.colors.text3),
            filled: true,
            fillColor: skin.colors.cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.design.radius.lg),
              borderSide: BorderSide(color: skin.colors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.design.radius.lg),
              borderSide: BorderSide(color: MistralColors.primary, width: 2),
            ),
          ),
          onSubmitted: (_) => _showAnswer ? _nextWord() : _checkAnswer(),
        ),
        const SizedBox(height: 16),
        if (_showAnswer) ...[
          Text(
            _feedback,
            style: MistralTypography.heading5.copyWith(
              color: _feedback.startsWith('✓') ? MistralColors.success : MistralColors.danger,
            ),
          ),
          const SizedBox(height: 16),
        ],
        const Spacer(),
        // 按钮组
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _showAnswer ? _nextWord : _checkAnswer,
            style: ElevatedButton.styleFrom(
              backgroundColor: MistralColors.primary,
              foregroundColor: AppColors.white100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(_showAnswer ? '下一个' : '确认'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
