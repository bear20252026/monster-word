// 由账号4生成
// 学习页：1:1 复刻原版 activity_learn.xml
// 结构：全屏背景 + 顶部栏(返回/进度/更多) + 上半单词区(单词40dp+音标+发音)
//      + 下半释义区 + 底部操作栏(认识/模糊/看答案 → 下一词/词根解析/看例句)
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/example_parser.dart';
import '../data/wordbook_database.dart';
import '../engine/srs_engine.dart';
import '../state/learning_state.dart';
import '../theme/app_theme.dart';
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
    final state = context.watch<LearningState>();
    final book = state.currentBook;
    final word = state.currentWord;

    return Scaffold(
      body: word == null
          ? const Center(child: Text('这本书还没有单词'))
          : Stack(
              children: [
                // ===== 全屏背景（原版 iv_background）=====
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.mainBgTop, AppColors.mainBgBottom],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      // ===== 顶部栏（原版 top_bar_container）=====
                      _TopBar(bookName: book?.name ?? '', state: state),
                      // ===== 上半：单词区（原版 rl_learnHalfTop）=====
                      Expanded(
                        flex: 5,
                        child: _WordArea(word: word, state: state),
                      ),
                      // ===== 下半：释义区（原版 rl_learnHalfBottom）=====
                      Expanded(
                        flex: 5,
                        child: _InterpretArea(word: word, state: state),
                      ),
                      // ===== 底部操作栏（原版 learn_review_bottom_bar）=====
                      _BottomBar(state: state),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// 顶部栏（原版 top_bar_container：返回 + 学习状态 + 更多）
class _TopBar extends StatelessWidget {
  final String bookName;
  final LearningState state;
  const _TopBar({required this.bookName, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          // 学习状态数字（原版 tv_learn_status，en_bold）
          Text(
            '${state.currentIndex + 1}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: state.total == 0 ? 0 : (state.currentIndex + 1) / state.total,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 更多选项（原版 iv_more_option）
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

/// 上半：单词 + 音标 + 发音（原版 word_container + PhoneticView）
class _WordArea extends StatelessWidget {
  final Word word;
  final LearningState state;
  const _WordArea({required this.word, required this.state});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 单词（原版 tv_word：40dp en_bold）
              Text(
                word.word,
                style: const TextStyle(
                  fontSize: AppDimens.learnMainWord,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              // 发音按钮（原版 center_speaker）
              IconButton(
                onPressed: () => _playWordAudio(context),
                icon: const Icon(Icons.volume_up, color: Colors.white, size: 26),
              ),
            ],
          ),
          // 音标（原版 PhoneticView）
          if (word.usPron.isNotEmpty || word.ukPron.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                [
                  if (word.usPron.isNotEmpty) '美 /${word.usPron}/',
                  if (word.ukPron.isNotEmpty) '英 /${word.ukPron}/',
                ].join('   '),
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _playWordAudio(BuildContext context) async {
    try {
      final player = AudioPlayer();
      await player.play(UrlSource(
        'http://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word.word)}&type=2',
      ));
    } catch (_) {}
  }
}

/// 下半：释义区（原版 rl_learnHalfBottom + ReviewMode_ENtoZH + learn_select_meaning）
/// 核心逻辑：必须先完成4选1选择，才显示释义
class _InterpretArea extends StatefulWidget {
  final Word word;
  final LearningState state;
  const _InterpretArea({required this.word, required this.state});

  @override
  State<_InterpretArea> createState() => _InterpretAreaState();
}

class _InterpretAreaState extends State<_InterpretArea> {
  int _selectedIndex = -1; // -1 = 未选择，0-3 = 选中的索引
  static const _labels = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    final word = widget.word;
    final state = widget.state;
    final lines = word.interpretLines;
    final examples = ExampleParser.parse(word.example);
    final showAnswer = _selectedIndex >= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: !showAnswer
          // ===== 4 选 1 选择题模式（必须选择才跳转）=====
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '请选择正确释义',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 4 个选项（带 A/B/C/D 标签）
                  for (int i = 0; i < state.choices.length && i < 4; i++)
                    _ChoiceOption(
                      label: _labels[i],
                      interpret: state.choices[i].interpret.toString(),
                      isAnswer: state.choices[i].word == word.word,
                      selected: false,
                      onTap: () {
                        setState(() => _selectedIndex = i);
                        // 评分：答对→good，答错→again
                        final correct = state.choices[i].word == word.word;
                        state.rate(correct ? RecallRating.good : RecallRating.again);
                      },
                    ),
                ],
              ),
            )
          // ===== 选择后：显示释义 + 正误反馈 + 例句 + 形近词 =====
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 正误反馈条
                  _buildFeedback(word, state),
                  const SizedBox(height: 16),
                  // 释义
                  if (lines.isNotEmpty)
                    ...lines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          line,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.4,
                            color: AppColors.black87,
                          ),
                        ),
                      ),
                    ),
                  // 例句
                  if (examples.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('例句',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black87)),
                    const SizedBox(height: 8),
                    ...examples.take(3).map((ex) => _ExampleTile(example: ex)),
                  ],
                  // 形近词
                  if (_confuseList.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('形近词',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black87)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _confuseList
                          .map((c) => Chip(
                                label: Text(c),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.orange.shade50,
                                side: BorderSide.none,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  /// 正误反馈条
  Widget _buildFeedback(Word word, LearningState state) {
    final isCorrect = state.choices[_selectedIndex].word == word.word;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect
            ? AppColors.successGreen.withValues(alpha: 0.1)
            : AppColors.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isCorrect
                  ? '✓ 正确！'
                  : '✗ 正确答案：${word.interpret.split('\n').first}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> get _confuseList {
    final t = widget.word.confuse.trim();
    if (t.isEmpty) return const [];
    if (t.startsWith('[')) {
      final inner = t.substring(1, t.length - 1);
      return inner.split(',').map((e) => e.trim().replaceAll('"', '')).where((e) => e.isNotEmpty).toList();
    }
    return [t];
  }
}

/// 4 选 1 选项（A/B/C/D 标签 + 正误反馈）
class _ChoiceOption extends StatelessWidget {
  final String label; // A/B/C/D
  final String interpret;
  final bool isAnswer;
  final bool selected;
  final VoidCallback? onTap;

  const _ChoiceOption({
    required this.label,
    required this.interpret,
    required this.isAnswer,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = !selected
        ? Colors.grey.shade50
        : isAnswer
            ? AppColors.successGreen.withValues(alpha: 0.1)
            : AppColors.errorRed.withValues(alpha: 0.1);
    final borderColor = !selected
        ? AppColors.dividerGrey
        : isAnswer
            ? AppColors.successGreen
            : AppColors.errorRed;
    final textColor = !selected
        ? AppColors.black87
        : isAnswer
            ? AppColors.successGreen
            : AppColors.errorRed;

    return GestureDetector(
      onTap: selected ? null : onTap,
      child: Container(
        height: 64,
        margin: const EdgeInsets.only(bottom: AppDimens.selectItemBottomMargins),
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.selectItemLrMargins),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppDimens.radiusNormal),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // A/B/C/D 标签
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: !selected
                    ? AppleColors.primary
                    : isAnswer
                        ? AppColors.successGreen
                        : AppColors.errorRed,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                interpret,
                style: TextStyle(fontSize: 15, color: textColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 例句条目（原版例句卡片）
class _ExampleTile extends StatelessWidget {
  final ExampleSentence example;
  const _ExampleTile({required this.example});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.dividerGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: AppColors.black87, height: 1.35),
                    children: example.highlightedParts
                        .map(
                          (p) => TextSpan(
                            text: p.text,
                            style: p.highlight
                                ? const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.successGreen,
                                  )
                                : null,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              IconButton(
                onPressed: _playExample,
                icon: const Icon(Icons.play_circle_outline),
                color: AppColors.successGreen,
                iconSize: 22,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (example.cn.isNotEmpty)
            Text(
              example.cn,
              style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
          if (example.source.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                example.source,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _playExample() async {
    try {
      final player = AudioPlayer();
      await player.play(UrlSource(
        'http://audio.beingfine.cn/sentence/audio/${example.source.isNotEmpty ? example.source : ''}',
      ));
    } catch (_) {}
  }
}

/// 底部操作栏（原版 learn_review_bottom_bar）
/// 底部操作栏（原版 learn_review_bottom_bar）
/// 核心修复：未选答案时只显示提示文字，选完后显示评分按钮
class _BottomBar extends StatelessWidget {
  final LearningState state;
  const _BottomBar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      color: Colors.transparent,
      child: state.showAnswer ? _buildAfterAnswer() : _buildBeforeAnswer(),
    );
  }

  /// 未选答案：提示用户先选择（不给"看答案"按钮）
  Widget _buildBeforeAnswer() {
    return Container(
      height: 48,
      alignment: Alignment.center,
      child: Text(
        '请从上方选择正确释义',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  /// 已选答案：下一词 / 不认识 / 熟练
  Widget _buildAfterAnswer() {
    return Row(
      children: [
        _LearnButton(
          label: '下一词',
          color: AppColors.successGreen,
          onTap: state.next,
        ),
        _LearnButton(
          label: '不认识',
          color: AppColors.errorRed,
          onTap: () => state.rate(RecallRating.again),
        ),
        _LearnButton(
          label: '熟练',
          color: AppColors.successGreen,
          onTap: () => state.rate(RecallRating.easy),
        ),
      ],
    );
  }
}

/// 学习按钮（复刻原版 LearnButton：圆角 8dp，16dp 字）
class _LearnButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _LearnButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: AppDimens.bottomBarBtnMargin),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppDimens.radiusNormal),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: AppDimens.learnBtnTextSize,
                color: AppColors.white100,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
