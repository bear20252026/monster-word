// 由账号4生成
// 学习页：Mistral AI 设计风格
// 流程：4选1 → 选错标红重选 → 选对标绿 → 进字典详情页 → 下一词
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/srs_engine.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});
  static const routeName = '/learn';

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final state = context.watch<LearningState>();
    final word = state.currentWord;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: word == null
          ? const Center(child: Text('暂无单词'))
          : SafeArea(
              child: Column(
                children: [
                  _TopBar(skin: skin, state: state),
                  Expanded(flex: 4, child: _WordArea(word: word, skin: skin)),
                  Expanded(flex: 6, child: _QuizArea(word: word, state: state)),
                ],
              ),
            ),
    );
  }
}

/// 顶部导航栏
class _TopBar extends StatelessWidget {
  final SkinSystem skin;
  final LearningState state;
  const _TopBar({required this.skin, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.navH,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        border: Border(bottom: BorderSide(color: skin.colors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('${state.currentIndex + 1}/${state.total}',
            style: MistralTypography.captionBold.copyWith(color: skin.colors.accent)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: state.total == 0 ? 0 : (state.currentIndex + 1) / state.total,
                minHeight: 3,
                backgroundColor: skin.colors.divider,
                valueColor: AlwaysStoppedAnimation(skin.colors.accent),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 20),
            color: skin.colors.text3,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

/// 上半：单词 + 音标 + 发音按钮
class _WordArea extends StatelessWidget {
  final dynamic word;
  final SkinSystem skin;
  const _WordArea({required this.word, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(word.word,
                  style: MistralTypography.heading1.copyWith(color: skin.colors.text1, fontSize: 44)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    try {
                      final player = AudioPlayer();
                      await player.play(UrlSource(
                        'http://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word.word)}&type=2'));
                    } catch (_) {}
                  },
                  child: Icon(Icons.volume_up_outlined, color: skin.colors.accent, size: 28),
                ),
              ],
            ),
            if (word.usPron.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('/${word.usPron}/',
                style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 下半：4选1 选错标红重选，选对标绿进字典详情页
class _QuizArea extends StatefulWidget {
  final dynamic word;
  final LearningState state;
  const _QuizArea({required this.word, required this.state});

  @override
  State<_QuizArea> createState() => _QuizAreaState();
}

class _QuizAreaState extends State<_QuizArea> {
  int _wrongIndex = -1; // -1=未选错
  static const _labels = ['A', 'B', 'C', 'D'];

  @override
  void didUpdateWidget(covariant _QuizArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.word != widget.word.word) _wrongIndex = -1;
  }

  void _onChoice(int i) {
    final isCorrect = widget.state.choices[i].word == widget.word.word;
    if (isCorrect) {
      // 选对：评分，跳转字典详情页
      widget.state.rate(RecallRating.good);
      setState(() {});
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) Navigator.pushNamed(context, '/word_detail');
      });
    } else {
      // 选错：标红，继续重选
      setState(() => _wrongIndex = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    final state = widget.state;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: skin.colors.cardBgAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: skin.colors.divider, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_wrongIndex >= 0 ? '请再选出正确答案' : '请选择正确释义',
              style: MistralTypography.captionBold.copyWith(
                color: _wrongIndex >= 0 ? skin.colors.danger : skin.colors.text3)),
            const SizedBox(height: 12),
            for (int i = 0; i < state.choices.length && i < 4; i++)
              _buildChoice(i, skin),
          ],
        ),
      ),
    );
  }

  Widget _buildChoice(int i, SkinSystem skin) {
    final choice = widget.state.choices[i];
    final isWrong = i == _wrongIndex;
    final interpret = choice.interpret.toString();

    return GestureDetector(
      onTap: () => _onChoice(i),
      child: Container(
        height: 56,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isWrong
              ? skin.colors.danger.withValues(alpha: 0.1)
              : skin.colors.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isWrong ? skin.colors.danger : skin.colors.divider,
            width: isWrong ? 1.5 : 0.5),
        ),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: isWrong ? skin.colors.danger : skin.colors.accent,
              shape: BoxShape.circle),
            child: Center(child: Text(
              _labels[i],
              style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(interpret,
            style: MistralTypography.bodyMd.copyWith(
              color: isWrong ? skin.colors.danger : skin.colors.text1),
            maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}
