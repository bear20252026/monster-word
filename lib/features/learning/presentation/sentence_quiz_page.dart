// 由 Claude 团队生成 | Monster Word App

// 句子测验：给出中文释义 → 选择正确的英文句子
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/nav_utils.dart';
import 'package:word_app/core/parsers/example_parser.dart';
import 'package:word_app/core/presentation/responsive.dart';
import '../../../models/word.dart';
import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';
import 'learning_session_state.dart';

class SentenceQuizPage extends StatefulWidget {
  const SentenceQuizPage({super.key});

  static const routeName = '/sentence_quiz';

  @override
  State<SentenceQuizPage> createState() => _SentenceQuizPageState();
}

class _SentenceQuizPageState extends State<SentenceQuizPage> {
  List<Word> _words = [];
  int _currentIndex = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  bool _loading = true;
  bool _showAnswer = false;
  int _selectedIndex = -1;
  List<_QuizOption> _options = [];

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      final session = context.read<LearningSessionState>();
      final words = session.queue.where((w) => w.example.isNotEmpty).toList();
      if (!mounted) return;
      setState(() {
        _words = words;
        _loading = false;
      });
      if (words.isNotEmpty) {
        _generateOptions();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _generateOptions() {
    if (_words.isEmpty) return;
    final current = _words[_currentIndex];
    final sentences = ExampleParser.parse(current.example);
    final correctSentence = sentences.isNotEmpty ? sentences.first.en : current.example;

    // 生成干扰项：从其他单词的例句中随机抽取
    final distractors = <String>[];
    final rng = Random();
    for (int i = 0; i < _words.length && distractors.length < 3; i++) {
      if (i == _currentIndex) continue;
      final otherSentences = ExampleParser.parse(_words[i].example);
      if (otherSentences.isNotEmpty) {
        distractors.add(otherSentences.first.en);
      }
    }

    final options = <_QuizOption>[
      _QuizOption(correctSentence, isCorrect: true),
      ...distractors.map((s) => _QuizOption(s, isCorrect: false)),
    ];
    options.shuffle(rng);

    setState(() {
      _options = options;
      _selectedIndex = -1;
      _showAnswer = false;
    });
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

  void _onSelect(int index) {
    if (_showAnswer) return;
    setState(() {
      _selectedIndex = index;
      _showAnswer = true;
      if (_options[index].isCorrect) {
        _correctCount++;
      } else {
        _wrongCount++;
      }
    });
  }

  void _next() {
    if (_currentIndex >= _words.length - 1) {
      _showResultDialog();
      return;
    }
    setState(() => _currentIndex++);
    _generateOptions();
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
        title: Text('测验完成', style: MistralTypography.heading4.copyWith(color: context.skin.colors.text1)),
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
              _reset();
            },
            style: ElevatedButton.styleFrom(backgroundColor: MistralColors.primary, foregroundColor: Colors.white),
            child: const Text('再来一次'),
          ),
        ],
      ),
    );
  }

  void _reset() {
    setState(() {
      _currentIndex = 0;
      _correctCount = 0;
      _wrongCount = 0;
      _showAnswer = false;
      _selectedIndex = -1;
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
              Text('暂无带例句的单词', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
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
          Text('句子测验', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 中文释义提示
        Text(
          '请选择正确的英文句子：',
          style: MistralTypography.bodyBold.copyWith(color: skin.colors.text2),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: skin.colors.cardBgAlt,
            borderRadius: BorderRadius.circular(context.design.radius.lg),
          ),
          child: Text(
            _currentWord.cleanInterpret,
            style: MistralTypography.heading4.copyWith(color: skin.colors.text1),
          ),
        ),
        const SizedBox(height: 24),
        // 选项列表
        for (int i = 0; i < _options.length; i++)
          _buildOptionItem(i, _options[i], skin, resp),
        const SizedBox(height: 24),
        if (_showAnswer)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: MistralColors.primary,
                foregroundColor: AppColors.white100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('下一个'),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOptionItem(int index, _QuizOption option, SkinSystem skin, AppResponsive resp) {
    final isSelected = _selectedIndex == index;
    Color borderColor = skin.colors.divider;
    Color bgColor = skin.colors.cardBg;

    if (_showAnswer) {
      if (option.isCorrect) {
        borderColor = MistralColors.success;
        bgColor = MistralColors.success.withValues(alpha: 0.1);
      } else if (isSelected) {
        borderColor = MistralColors.danger;
        bgColor = MistralColors.danger.withValues(alpha: 0.1);
      }
    } else if (isSelected) {
      borderColor = MistralColors.primary;
      bgColor = MistralColors.primary.withValues(alpha: 0.1);
    }

    return GestureDetector(
      onTap: () => _onSelect(index),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(context.design.radius.lg),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: borderColor == skin.colors.divider
                    ? skin.colors.cardBgAlt
                    : borderColor.withValues(alpha: 0.2),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index), // A, B, C, D
                  style: MistralTypography.bodyBold.copyWith(color: borderColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.text,
                style: MistralTypography.body.copyWith(color: skin.colors.text1),
              ),
            ),
            if (_showAnswer && option.isCorrect)
              Icon(Icons.check_circle, color: MistralColors.success, size: 20)
            else if (_showAnswer && isSelected && !option.isCorrect)
              Icon(Icons.cancel, color: MistralColors.danger, size: 20),
          ],
        ),
      ),
    );
  }
}

class _QuizOption {
  final String text;
  final bool isCorrect;
  const _QuizOption(this.text, {required this.isCorrect});
}
