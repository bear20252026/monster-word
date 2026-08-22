// 由账号4生成
// 学习页：Mistral AI 设计风格
// 奶油黄卡片 + 橙色 CTA + Charter 衬线单词 + Inter 无衬线正文
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/example_parser.dart';
import '../engine/srs_engine.dart';
import '../state/learning_state.dart';
import '../theme/app_theme.dart';
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
                  Expanded(flex: 6, child: _InterpretArea(word: word, state: state)),
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
                  style: MistralTypography.heading1.copyWith(color: skin.colors.text1, fontSize: 44),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _playAudio(word.word),
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

  Future<void> _playAudio(String w) async {
    try {
      final player = AudioPlayer();
      await player.play(UrlSource('http://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(w)}&type=2'));
    } catch (_) {}
  }
}

/// 下半：4选1 → 原地变色 → 例句 → 下一词
class _InterpretArea extends StatefulWidget {
  final dynamic word;
  final LearningState state;
  const _InterpretArea({required this.word, required this.state});

  @override
  State<_InterpretArea> createState() => _InterpretAreaState();
}

class _InterpretAreaState extends State<_InterpretArea> {
  int _selectedIndex = -1;
  static const _labels = ['A', 'B', 'C', 'D'];

  @override
  void didUpdateWidget(covariant _InterpretArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.word != widget.word.word) _selectedIndex = -1;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final word = widget.word;
    final state = widget.state;
    final lines = word.interpretLines;
    final examples = ExampleParser.parse(word.example);
    final answered = _selectedIndex >= 0;
    final correct = answered && state.choices[_selectedIndex].word == word.word;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        // 奶油黄卡片（Mistral card-cream）
        color: skin.colors.cardBgAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: skin.colors.divider, width: 0.5),
      ),
      child: !answered
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('请选择正确释义',
                    style: MistralTypography.captionBold.copyWith(color: skin.colors.text3)),
                  const SizedBox(height: 12),
                  for (int i = 0; i < state.choices.length && i < 4; i++)
                    _ChoiceOption(
                      label: _labels[i],
                      interpret: state.choices[i].interpret.toString(),
                      isAnswer: state.choices[i].word == word.word,
                      selected: false, skin: skin,
                      onTap: () {
                        setState(() => _selectedIndex = i);
                        final isCorrect = state.choices[i].word == word.word;
                        state.rate(isCorrect ? RecallRating.good : RecallRating.again);
                      },
                    ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < state.choices.length && i < 4; i++)
                    _ChoiceOption(
                      label: _labels[i],
                      interpret: state.choices[i].interpret.toString(),
                      isAnswer: state.choices[i].word == word.word,
                      selected: i == _selectedIndex, skin: skin,
                    ),
                  const SizedBox(height: 16),
                  // 正误反馈
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: correct
                          ? skin.colors.success.withValues(alpha: 0.1)
                          : skin.colors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: correct ? skin.colors.success : skin.colors.danger),
                    ),
                    child: Row(children: [
                      Icon(correct ? Icons.check_circle : Icons.cancel,
                        color: correct ? skin.colors.success : skin.colors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        correct ? '✓ 正确！' : '✗ 正确答案：${word.interpret.split('\n').first}',
                        style: MistralTypography.bodyMd.copyWith(
                          color: correct ? skin.colors.success : skin.colors.danger),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  ...lines.map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(line, style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1)),
                  )),
                  if (examples.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('例句', style: MistralTypography.captionBold.copyWith(color: skin.colors.text2)),
                    const SizedBox(height: 8),
                    ...examples.take(2).map((ex) => _ExampleTile(ex, skin)),
                  ],
                  const SizedBox(height: 16),
                  // 橙色 CTA 按钮（Mistral button-primary）
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: FilledButton(
                      onPressed: () => state.next(),
                      style: FilledButton.styleFrom(
                        backgroundColor: skin.colors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      child: Text('下一词',
                        style: MistralTypography.buttonMd.copyWith(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// 4选1选项（Mistral pill-tab 风格）
class _ChoiceOption extends StatelessWidget {
  final String label;
  final String interpret;
  final bool isAnswer;
  final bool selected;
  final SkinSystem skin;
  final VoidCallback? onTap;

  const _ChoiceOption({
    required this.label, required this.interpret, required this.isAnswer,
    this.selected = false, required this.skin, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final answered = selected || onTap == null;
    final circleColor = !answered ? skin.colors.accent
        : isAnswer ? skin.colors.success : skin.colors.danger;
    final bgColor = !answered ? skin.colors.cardBg
        : isAnswer ? skin.colors.success.withValues(alpha: 0.08)
        : skin.colors.danger.withValues(alpha: 0.08);
    final borderColor = !answered ? skin.colors.divider
        : isAnswer ? skin.colors.success : skin.colors.danger;

    return GestureDetector(
      onTap: answered ? null : onTap,
      child: Container(
        height: 56,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: borderColor, width: answered ? 1.5 : 0.5),
        ),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
            child: Center(child: Text(label,
              style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(interpret,
            style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1),
            maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

/// 例句条目
class _ExampleTile extends StatelessWidget {
  final ExampleSentence example;
  final SkinSystem skin;
  const _ExampleTile(this.example, this.skin);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: skin.colors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichText(text: TextSpan(
          style: MistralTypography.bodySm.copyWith(color: skin.colors.text1, height: 1.4),
          children: example.highlightedParts.map((p) => TextSpan(
            text: p.text,
            style: p.highlight
                ? TextStyle(fontWeight: FontWeight.bold, color: skin.colors.accent)
                : null,
          )).toList(),
        )),
        if (example.cn.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(example.cn, style: MistralTypography.micro.copyWith(color: skin.colors.text3)),
        ],
      ]),
    );
  }
}
