// 由账号4生成
// L3 复习页：壁纸沉浸 + 四选一 + 认识/模糊/忘记了 下划线三键
// 翻译自 Figma 03a-screens-learning.json review_session
import 'package:flutter/material.dart';

import '../data/example_parser.dart';
import '../data/wordbook_database.dart';
import '../engine/core_engine.dart';
import '../engine/srs_engine.dart';
import '../engine/super_memory_engine.dart';
import '../hooks/responsive.dart';
import '../models/bb_word_process.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/glass_widgets.dart';

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
    final sample = await WordBookDatabase.instance.searchWords('a', limit: 20);
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
    _choices = _engine.shuffleList(choices);
    _selectedChoice = null;
  }

  void _rate(RecallRating rating) {
    switch (rating) {
      case RecallRating.again: _engine.iDontKnow();
      case RecallRating.hard: _engine.iMayKnow();
      case RecallRating.good: _engine.iReallyKnow();
      case RecallRating.easy: _engine.tooEasy();
    }
    _done++;
    _showAnswer = false;
    _regenerateChoices();
    setState(() {});
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

    return Scaffold(
      body: WallpaperBg(
        child: SafeArea(
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
              // 底部下划线三键
              _buildVerdictRow(skin),
            ],
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
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            '$_done/$_total',
            style: AppTypography.caption.copyWith(color: skin.colors.onGlassText1),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.undo, color: skin.colors.onGlassText2, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.star_border, color: skin.colors.onGlassText2, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.more_horiz, color: skin.colors.onGlassText2, size: 20),
            onPressed: () {},
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

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedChoice = i;
                  _showAnswer = true;
                });
                _rate(isAnswer ? RecallRating.good : RecallRating.again);
              },
              child: Container(
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
                  ),
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
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(word.word,
              style: AppTypography.heroWord.copyWith(
                  fontSize: resp.heroFontSize, color: skin.colors.onGlassText1)),
          const SizedBox(height: 16),
          if (word.interpret.isNotEmpty)
            Text(word.interpret,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Row(
        children: [
          _verdictBtn('认识', skin.colors.teal, () => _rate(RecallRating.good), skin),
          _verdictBtn('模糊', skin.colors.accent, () => _rate(RecallRating.hard), skin),
          _verdictBtn('忘记了', skin.colors.danger, () => _rate(RecallRating.again), skin),
        ],
      ),
    );
  }

  Widget _verdictBtn(String label, Color color, VoidCallback onTap, SkinSystem skin) {
    return Expanded(
      child: GestureDetector(
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
      ),
    );
  }

  Widget _buildDone() {
    return WallpaperBg(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 72),
            const SizedBox(height: 16),
            const Text('今日复习完成！',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text('共复习 $_done 个单词',
                style: AppTypography.body.copyWith(color: Colors.white70)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
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
        color: const Color(0xEBFFFBF0),
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
                      ? const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2FA89F))
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
