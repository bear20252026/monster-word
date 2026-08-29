// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 QuickSpellActivity
// 快速拼写挑战：限时拼写 + 即时反馈
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/nav_utils.dart';
import '../../../models/word.dart';
import '../../../hooks/responsive.dart';
import '../../../player/system_tts.dart';
import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';
import 'learning_session_state.dart';

class QuickSpellPage extends StatefulWidget {
  const QuickSpellPage({super.key});

  static const routeName = '/quick_spell';

  @override
  State<QuickSpellPage> createState() => _QuickSpellPageState();
}

class _QuickSpellPageState extends State<QuickSpellPage> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  late SystemTts _tts;

  /// 挑战单词列表
  List<Word> _words = [];
  int _currentIndex = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  bool _loading = true;
  bool _showAnswer = false;
  bool _finished = false;
  String _feedback = '';

  /// 计时
  Timer? _timer;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _tts = SystemTts();
    _loadWords();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    _timer?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadWords() async {
    try {
      // 从学习会话状态获取队列单词（最多 20 个）
      final session = context.read<LearningSessionState>();
      final words = session.queue.take(20).toList();
      if (!mounted) return;
      setState(() {
        _words = words;
        _loading = false;
      });
      if (words.isNotEmpty) {
        _startTimer();
        _focusNode.requestFocus();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _startTimer() {
    _secondsLeft = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _onTimeUp();
      }
    });
  }

  void _onTimeUp() {
    setState(() {
      _finished = true;
    });
    _timer?.cancel();
    _showResultDialog();
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
      // 全部完成
      setState(() => _finished = true);
      _timer?.cancel();
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

  void _speakWord() {
    if (_words.isEmpty) return;
    _tts.speakEnglish(_currentWord.word);
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
        title: Text('挑战完成', style: MistralTypography.heading4.copyWith(color: context.skin.colors.text1)),
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
              _resetChallenge();
            },
            style: ElevatedButton.styleFrom(backgroundColor: MistralColors.primary, foregroundColor: Colors.white),
            child: const Text('再来一次'),
          ),
        ],
      ),
    );
  }

  void _resetChallenge() {
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
              Icon(Icons.keyboard, size: 64, color: skin.colors.text3),
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
                    child: _finished ? _buildFinishView(skin, resp) : _buildPlayView(skin, resp),
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
            onPressed: () {
              _timer?.cancel();
              NavUtils.safePop(context);
            },
          ),
          const SizedBox(width: 4),
          Text('快速拼写', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
          const Spacer(),
          // 计时
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _secondsLeft <= 10 ? MistralColors.danger.withValues(alpha: 0.1) : MistralColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(context.design.radius.pill),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: _secondsLeft <= 10 ? MistralColors.danger : MistralColors.primary),
                const SizedBox(width: 4),
                Text(
                  '$_secondsLeft s',
                  style: MistralTypography.bodyBold.copyWith(
                    color: _secondsLeft <= 10 ? MistralColors.danger : MistralColors.primary,
                  ),
                ),
              ],
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
        // 进度
        Text('${_currentIndex + 1} / ${_words.length}', style: MistralTypography.heading5.copyWith(color: skin.colors.text3)),
        const SizedBox(height: 8),
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
                style: MistralTypography.heading4.copyWith(color: skin.colors.text1),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // 发音按钮
              GestureDetector(
                onTap: _speakWord,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: MistralColors.cream,
                    borderRadius: BorderRadius.circular(context.design.radius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up_outlined, size: 18, color: MistralColors.primary),
                      const SizedBox(width: 6),
                      Text('听发音', style: MistralTypography.bodySm.copyWith(color: MistralColors.primary)),
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
        // 反馈
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
        Row(
          children: [
            if (!_showAnswer) ...[
              Expanded(
                child: ElevatedButton(
                  onPressed: _checkAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MistralColors.primary,
                    foregroundColor: AppColors.white100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('确认'),
                ),
              ),
            ] else ...[
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextWord,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MistralColors.primary,
                    foregroundColor: AppColors.white100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('下一个'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFinishView(SkinSystem skin, AppResponsive resp) {
    final total = _correctCount + _wrongCount;
    final accuracy = total > 0 ? (_correctCount / total * 100).toStringAsFixed(1) : '0';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.emoji_events, size: 64, color: MistralColors.sunshine300),
        const SizedBox(height: 16),
        Text('挑战结束', style: MistralTypography.heading3.copyWith(color: skin.colors.text1)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: skin.colors.cardBg,
            borderRadius: BorderRadius.circular(context.design.radius.lg),
            border: Border.all(color: skin.colors.divider),
          ),
          child: Column(
            children: [
              Text('正确率：$accuracy%', style: MistralTypography.heading4.copyWith(color: MistralColors.primary)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text('$_correctCount', style: MistralTypography.heading3.copyWith(color: MistralColors.success)),
                      Text('正确', style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('$_wrongCount', style: MistralTypography.heading3.copyWith(color: MistralColors.danger)),
                      Text('错误', style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _resetChallenge,
            style: ElevatedButton.styleFrom(
              backgroundColor: MistralColors.primary,
              foregroundColor: AppColors.white100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('再来一次'),
          ),
        ),
      ],
    );
  }
}
