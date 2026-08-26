// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// L3 复习页：壁纸沉浸 + 四选一 + 认识/模糊/忘记了 下划线三键
// 翻译自 Figma 03a-screens-learning.json review_session
import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../data/example_parser.dart';
import 'package:provider/provider.dart';
import '../engine/core_engine.dart' show WordChoicePair;
import '../engine/super_memory_engine.dart';
import '../engine/fsrs6_engine.dart' show FsrsRating;
import '../hooks/responsive.dart';
import '../repositories/word_repository.dart';
import '../models/bb_word_process.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/scale_down_on_press.dart';
import '../widgets/session_exit_guard.dart';

/// 兼容性别名：RecallRating = FsrsRating
typedef RecallRating = FsrsRating;

class ReviewSession extends StatefulWidget {
  const ReviewSession({super.key});
  static const routeName = '/review_session';

  @override
  State<ReviewSession> createState() => _ReviewSessionState();
}

class _ReviewSessionState extends State<ReviewSession> {
  final SuperMemoryEngine _engine = SuperMemoryEngine();
  bool _initialized = false;
  bool _showAnswer = false;
  List<WordChoicePair> _choices = [];
  int _total = 0;
  int _done = 0;
  int? _selectedChoice; // 四选一选中项

  @override
  void initState() {
    super.initState();
    _initReview();
  }

  Future<void> _initReview() async {
    final dueWords = <BBWordProcess>[];
    final sample = await sl<WordRepository>().searchWords('a', limit: 20);
    for (final w in sample) {
      dueWords.add(BBWordProcess(
        word: w.word, wordId: w.id, interpret: w.interpret,
        usPron: w.usPron, ukPron: w.ukPron, example: w.example,
      ));
    }
    _engine.init(dueWords);
    _total = _engine.totalNum;
    _done = 0;
    _initialized = true;
    _regenerateChoices();
    if (mounted) setState(() {});
  }

  void _regenerateChoices() {
    final current = _engine.currentWord();
    if (current == null) return;
    final confuses = _engine.confuseItemsForChoice(current);
    final choices = <WordChoicePair>[
      WordChoicePair(current.word, current.interpret),
    ];
    for (final c in confuses) {
      choices.add(WordChoicePair(c.i, c.i));
    }
    // 确保始终有4个选项，不够则填充通用释义
    final fallbackOptions = [
      WordChoicePair('option_1', '通用释义1'),
      WordChoicePair('option_2', '通用释义2'),
      WordChoicePair('option_3', '通用释义3'),
      WordChoicePair('option_4', '通用释义4'),
      WordChoicePair('option_5', '通用释义5'),
    ];
    var fallbackIdx = 0;
    while (choices.length < 4) {
      choices.add(fallbackOptions[fallbackIdx % fallbackOptions.length]);
      fallbackIdx++;
    }
    // 确保选项已打乱顺序
    _choices = _engine.shuffleList(choices);
    _selectedChoice = null;
  }

  void _rate(RecallRating rating) {
    // 同步到 Leitner 引擎
    switch (rating) {
      case RecallRating.again: _engine.iDontKnow();
      case RecallRating.hard: _engine.iMayKnow();
      case RecallRating.good: _engine.iReallyKnow();
      case RecallRating.easy: _engine.tooEasy();
    }
    // 同步到 FSRS-6 算法（精确记忆评估）
    final fsrsRating = switch (rating) {
      RecallRating.again => FsrsRating.again,
      RecallRating.hard => FsrsRating.hard,
      RecallRating.good => FsrsRating.good,
      RecallRating.easy => FsrsRating.easy,
    };
    final currentWord = _engine.currentWord();
    if (currentWord != null && mounted) {
      context.read<LearningState>().rate(fsrsRating);
    }
    _done++;
    _showAnswer = false;
    _selectedChoice = null;
    _regenerateChoices();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final word = _engine.currentWord();
    if (word == null) return _buildDone();

    final skin = context.skin;
    final resp = context.responsive;

    // 返回保护：系统返回需确认，防止误触丢失复习进度
    return SessionExitGuard(
      subject: '本次复习',
      child: Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: resp.contentMaxWidth),
            child: Column(
              children: [
                // 透明导航栏
                _buildNav(skin, resp),
                // 四选一区（未答）或释义区（已答）
                Expanded(
                  child: _showAnswer
                      ? _buildAnswer(word, skin, resp)
                      : _buildQuiz(word, skin, resp),
                ),
                // 底部下划线三键（仅在显示答案后显示）
                if (_showAnswer) _buildVerdictRow(skin),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  /// 透明导航栏
  Widget _buildNav(SkinSystem skin, AppResponsive resp) {
    return Container(
      height: AppSpacing.navH,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 20, color: skin.colors.onGlassText1),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            '$_done/$_total',
            style: AppTypography.caption.copyWith(color: skin.colors.onGlassText1),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.undo, color: skin.colors.onGlassText2, size: 20),
            tooltip: '撤销',
            onPressed: () {
              // TODO: 实现撤销逻辑
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('撤销功能开发中...'), duration: Duration(seconds: 1)),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.star_border, color: skin.colors.onGlassText2, size: 20),
            tooltip: '收藏',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('收藏功能开发中...'), duration: Duration(seconds: 1)),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.more_horiz, color: skin.colors.onGlassText2, size: 20),
            tooltip: '更多',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('更多操作开发中...'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 四选一（原版 QuizOption）
  Widget _buildQuiz(BBWordProcess word, SkinSystem skin, AppResponsive resp) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 单词
          Text(
            word.word,
            style: AppTypography.heroWord.copyWith(
              fontSize: resp.heroFontSize,
              color: skin.colors.onGlassText1,
            ),
          ),
          const SizedBox(height: 8),
          if (word.usPron.isNotEmpty)
            Text(
              '/${word.usPron}/',
              style: AppTypography.caption.copyWith(color: skin.colors.onGlassText2),
            ),
          const SizedBox(height: 32),
          // 四选一选项
          ...List.generate(_choices.length, (i) {
            final c = _choices[i];
            final isAnswer = c.word == word.word;
            final selected = _selectedChoice == i;
            final correct = selected && isAnswer;
            final wrong = selected && !isAnswer;

            return ScaleDownOnPress(
              onTap: () {
                _rate(isAnswer ? RecallRating.good : RecallRating.again);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: correct
                      ? skin.colors.quizCorrectBg
                      : wrong
                          ? skin.colors.quizWrongBg
                          : skin.colors.modalGlassBg,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: correct
                        ? skin.colors.quizCorrectText
                        : wrong
                            ? skin.colors.quizWrongText
                            : skin.colors.divider,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected
                      ? [BoxShadow(color: skin.colors.accent.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Text(
                  c.interpret,
                  style: AppTypography.body.copyWith(
                    color: correct
                        ? skin.colors.quizCorrectText
                        : wrong
                            ? skin.colors.quizWrongText
                            : skin.colors.text1,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 已答后：释义+例句
  Widget _buildAnswer(BBWordProcess word, SkinSystem skin, AppResponsive resp) {
    final examples = ExampleParser.parse(word.example);
    final meaningText = word.hasStructuredDefinitions
        ? word.formattedDefinitions
        : word.cleanInterpret;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(word.word,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.heroWord.copyWith(
                  fontSize: resp.heroFontSize, color: skin.colors.onGlassText1)),
          const SizedBox(height: 16),
          if (meaningText.isNotEmpty)
            Text(meaningText,
                style: AppTypography.body.copyWith(
                    color: skin.colors.onGlassText1, height: 1.5)),
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...examples.take(2).map((ex) => _ExampleTile(example: ex, skin: skin)),
          ],
        ],
      ),
    );
  }

  /// 认识(青) / 模糊(橙) / 忘记了(红) 下划线三键
  Widget _buildVerdictRow(SkinSystem skin) {
    final resp = context.responsive;
    return Container(
      padding: EdgeInsets.fromLTRB(
        resp.horizontalPadding,
        12,
        resp.horizontalPadding,
        16,
      ),
      child: Row(
        children: [
          Expanded(child: _verdictBtn('忘记了', skin.colors.danger, () => _rate(RecallRating.again), skin)),
          const SizedBox(width: 8),
          Expanded(child: _verdictBtn('模糊', skin.colors.accent, () => _rate(RecallRating.hard), skin)),
          const SizedBox(width: 8),
          Expanded(child: _verdictBtn('认识', skin.colors.teal, () => _rate(RecallRating.good), skin)),
          const SizedBox(width: 8),
          Expanded(child: _verdictBtn('太简单', skin.colors.success, () => _rate(RecallRating.easy), skin)),
        ],
      ),
    );
  }

  Widget _verdictBtn(String label, Color color, VoidCallback onTap, SkinSystem skin) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: color, width: AppUnderline.thickness)),
        ),
        child: Center(
          child: Text(label,
              style: AppTypography.body.copyWith(color: skin.colors.onGlassText1)),
        ),
      ),
    );
  }

  Widget _buildDone() {
    final skin = context.skin.colors;
    return Container(
      color: skin.pageBg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: skin.text1, size: 72),
            const SizedBox(height: 16),
            Text('今日复习完成！',
                style: MistralTypography.heading3.copyWith(fontWeight: FontWeight.bold, color: skin.text1)),
            const SizedBox(height: 8),
            Text('共复习 $_done 个单词',
                style: MistralTypography.bodySm.copyWith(color: skin.text2)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(backgroundColor: skin.accent),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 例句条目
class _ExampleTile extends StatelessWidget {
  final ExampleSentence example;
  final SkinSystem skin;
  const _ExampleTile({required this.example, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: skin.colors.cardBgAlt,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: AppTypography.body.copyWith(color: skin.colors.text1, height: 1.5),
              children: example.highlightedParts.map(
                (p) => TextSpan(
                  text: p.text,
                  style: p.highlight
                      ? TextStyle(fontWeight: FontWeight.bold, color: skin.colors.accent)
                      : null,
                ),
              ).toList(),
            ),
          ),
          if (example.cn.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(example.cn,
                style: AppTypography.caption.copyWith(color: skin.colors.text2)),
          ],
        ],
      ),
    );
  }
}
