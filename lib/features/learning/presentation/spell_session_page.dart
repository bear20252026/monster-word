// 由 Claude 团队生成 | Monster Word App

// 拼写会话：基于学习会话状态的拼写练习流程
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';

class SpellSessionPage extends StatefulWidget {
  const SpellSessionPage({super.key});

  static const routeName = '/spell_session';

  @override
  State<SpellSessionPage> createState() => _SpellSessionPageState();
}

class _SpellSessionPageState extends State<SpellSessionPage> {
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
        title: Text('拼写练习完成', style: MwTypography.heading4.copyWith(color: context.skin.colors.text1)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('正确：$_correctCount', style: MwTypography.body.copyWith(color: MwColors.success)),
            Text('错误：$_wrongCount', style: MwTypography.body.copyWith(color: MwColors.danger)),
            const SizedBox(height: 8),
            Text('正确率：$accuracy%', style: MwTypography.bodyBold.copyWith(color: context.skin.colors.text1)),
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
            style: ElevatedButton.styleFrom(backgroundColor: MwColors.primary, foregroundColor: Colors.white),
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
              Icon(Icons.check_circle_outline, size: 64, color: skin.colors.text3),
              const SizedBox(height: 16),
              Text('暂无待学习单词', style: MwTypography.body.copyWith(color: skin.colors.text3)),
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
          Text('拼写练习', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: MwColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(context.design.radius.pill),
            ),
            child: Text(
              '${_currentIndex + 1} / ${_words.length}',
              style: MwTypography.bodyBold.copyWith(color: MwColors.primary),
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
        // 释义提示
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: skin.colors.cardBgAlt,
            borderRadius: BorderRadius.circular(context.design.radius.lg),
          ),
          child: Column(
            children: [
              Text(
                _currentWord.cleanInterpret,
                style: MwTypography.heading4.copyWith(color: skin.colors.text1),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => context.read<AudioPlaybackState>().playWord(_currentWord.word),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: MwColors.cream,
                    borderRadius: BorderRadius.circular(context.design.radius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up_outlined, size: 18, color: MwColors.primary),
                      const SizedBox(width: 6),
                      Text('听发音', style: MwTypography.bodySm.copyWith(color: MwColors.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // 输入框
        TextField(
          controller: _inputController,
          focusNode: _focusNode,
          enabled: !_showAnswer,
          textAlign: TextAlign.center,
          style: AppTypography.heroWord.copyWith(color: skin.colors.text1),
          decoration: InputDecoration(
            hintText: '输入英文单词',
            hintStyle: MwTypography.body.copyWith(color: skin.colors.text3),
            filled: true,
            fillColor: skin.colors.cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.design.radius.lg),
              borderSide: BorderSide(color: skin.colors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.design.radius.lg),
              borderSide: BorderSide(color: MwColors.primary, width: 2),
            ),
          ),
          onSubmitted: (_) => _showAnswer ? _nextWord() : _checkAnswer(),
        ),
        const SizedBox(height: 16),
        if (_showAnswer) ...[
          Text(
            _feedback,
            style: MwTypography.heading5.copyWith(
              color: _feedback.startsWith('✓') ? MwColors.success : MwColors.danger,
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
              backgroundColor: MwColors.primary,
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
