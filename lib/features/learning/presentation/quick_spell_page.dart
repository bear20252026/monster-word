// 由 Claude 团队生成 | Monster Word App

// 快速拼写挑战：60 秒限时拼写（最多 20 词）。
// 判分/推进/结果页由共享脚手架托管；本页只额外拥有计时器。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/features/learning/presentation/spelling_quiz_flow.dart';
import 'package:word_app/core/audio/system_tts.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

class QuickSpellPage extends StatefulWidget {
  const QuickSpellPage({super.key});

  static const routeName = '/quick_spell';

  @override
  State<QuickSpellPage> createState() => _QuickSpellPageState();
}

class _QuickSpellPageState extends State<QuickSpellPage> {
  late final SystemTts _tts;
  Timer? _timer;
  int _secondsLeft = 60;
  late final SpellingQuizController _quiz;

  @override
  void initState() {
    super.initState();
    _tts = SystemTts();
    _quiz = SpellingQuizController(limit: 20, onStarted: _startTimer, onFinished: _cancelTimer);
    _quiz.load(() async => context.read<LearningSessionState>().queue.toList());
  }

  @override
  void dispose() {
    _cancelTimer();
    _tts.stop();
    _quiz.dispose();
    super.dispose();
  }

  void _startTimer() {
    _cancelTimer();
    _secondsLeft = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _quiz.finishByTime();
      }
    });
  }

  void _cancelTimer() => _timer?.cancel();

  @override
  Widget build(BuildContext context) {
    return SpellingQuizScaffold(
      controller: _quiz,
      title: '快速拼写',
      inputHint: '输入英文单词',
      finishTitle: '挑战结束',
      navTrailing: _buildTimerPill(),
      onExit: _cancelTimer,
      promptBuilder: (context, word) => QuizPromptCard(
        word: word,
        header: Text(
          '${_quiz.index + 1} / ${_quiz.total}',
          style: MwTypography.heading5.copyWith(color: context.skin.colors.text3),
          textAlign: TextAlign.center,
        ),
        onListen: () => _tts.speakEnglish(word.word),
      ),
    );
  }

  Widget _buildTimerPill() {
    final urgent = _secondsLeft <= 10;
    final color = urgent ? context.skin.colors.danger : context.skin.colors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(context.design.radius.pill),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 16, color: color),
          const SizedBox(width: 4),
          Text('$_secondsLeft s', style: MwTypography.bodyBold.copyWith(color: color)),
        ],
      ),
    );
  }
}
