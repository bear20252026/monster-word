// 由 Claude 团队生成 | Monster Word App

// 单词听写会话：只听发音拼单词。判分/推进/结果页由共享脚手架托管。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/features/learning/presentation/spelling_quiz_flow.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/theme/skin_system.dart';

class DictationSessionPage extends StatefulWidget {
  const DictationSessionPage({super.key});

  static const routeName = '/dictation_session';

  @override
  State<DictationSessionPage> createState() => _DictationSessionPageState();
}

class _DictationSessionPageState extends State<DictationSessionPage> {
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
      title: '单词听写',
      inputHint: '请输入单词',
      finishTitle: '听写完成',
      inputStyle: MwTypography.heading3,
      promptBuilder: (context, word) => _DictationPrompt(word: word),
    );
  }
}

/// 听写提示区：大发音圆钮（无释义——听音是唯一线索）。
class _DictationPrompt extends StatelessWidget {
  const _DictationPrompt({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => context.read<AudioPlaybackState>().playWord(word.word),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.skin.colors.cardBgAlt,
              border: Border.all(color: context.skin.colors.accent, width: 2),
            ),
            child: Icon(Icons.volume_up, size: 40, color: context.skin.colors.accent),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.read<AudioPlaybackState>().playWord(word.word),
          child: Text('点击播放', style: TextStyle(color: context.skin.colors.accent)),
        ),
      ],
    );
  }
}
