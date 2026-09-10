// 由 Claude 团队生成 | Monster Word App

// 拼写会话：看释义拼单词。判分/推进/结果页由共享脚手架托管。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/features/learning/presentation/spelling_quiz_flow.dart';

class SpellSessionPage extends StatefulWidget {
  const SpellSessionPage({super.key});

  static const routeName = '/spell_session';

  @override
  State<SpellSessionPage> createState() => _SpellSessionPageState();
}

class _SpellSessionPageState extends State<SpellSessionPage> {
  late final SpellingQuizController _quiz;

  @override
  void initState() {
    super.initState();
    _quiz = SpellingQuizController();
    _quiz.load(() async => context.read<LearningSessionState>().queue.toList());
  }

  @override
  void dispose() {
    _quiz.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SpellingQuizScaffold(
      controller: _quiz,
      title: '拼写练习',
      inputHint: '输入英文单词',
      finishTitle: '拼写练习完成',
      promptBuilder: (context, word) =>
          QuizPromptCard(word: word, onListen: () => context.read<AudioPlaybackState>().playWord(word.word)),
    );
  }
}
