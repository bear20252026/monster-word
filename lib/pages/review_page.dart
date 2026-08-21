// 由账号4生成
// 复习页：1:1 复刻原版 activity_review.xml
// 结构：全屏背景 + 顶部栏(返回/进度) + 上半单词区 + 下半释义/4选1 + 底部操作栏
// 调度逻辑：SuperMemoryEngine（到期词 + 测试模式，v3.2 源码 1:1）

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../data/example_parser.dart';
import '../data/wordbook_database.dart';
import '../engine/core_engine.dart';
import '../engine/srs_engine.dart';
import '../engine/super_memory_engine.dart';
import '../models/bb_word_process.dart';
import '../theme/app_theme.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  static const routeName = '/review';

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final SuperMemoryEngine _engine = SuperMemoryEngine();
  bool _initialized = false;
  bool _showAnswer = false;
  List<WordChoicePair> _choices = [];
  int _total = 0;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _initReview();
  }

  /// 初始化复习（到期调度：从词库拉取今日到期词）
  Future<void> _initReview() async {
    // 到期调度：取用户 SRS 卡片中到期词
    // 简化：从当前学习过的词中取待复习词（这里用词库搜索接口占位）
    final dueWords = <BBWordProcess>[];
    // 从词库取一批词作为复习池（真实实现：从 user_process 表按 reviewdate 筛选）
    final sample = await WordBookDatabase.instance.searchWords('a', limit: 20);
    for (final w in sample) {
      dueWords.add(BBWordProcess(
        word: w.word,
        wordId: w.id,
        interpret: w.interpret,
        usPron: w.usPron,
        ukPron: w.ukPron,
        example: w.example,
      ));
    }
    _engine.init(dueWords);
    _total = _engine.totalNum;
    _done = 0;
    _initialized = true;
    _regenerateChoices();
    if (mounted) setState(() {});
  }

  /// 生成 4 选 1 选项（原版 confuseItemsForChoice）
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
  }

  /// 评分（原版 iDontKnow/iMayKnow/iReallyKnow）
  void _rate(RecallRating rating) {
    switch (rating) {
      case RecallRating.again:
        _engine.iDontKnow();
      case RecallRating.hard:
        _engine.iMayKnow();
      case RecallRating.good:
        _engine.iReallyKnow();
      case RecallRating.easy:
        _engine.tooEasy();
    }
    _done++;
    _regenerateChoices();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final word = _engine.currentWord();

    return Scaffold(
      body: word == null
          ? _buildReviewDone()
          : Stack(
              children: [
                // 全屏背景（原版 iv_background）
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
                      // 顶部栏（原版 top_bar_container）
                      _buildTopBar(),
                      // 上半：单词区
                      Expanded(
                        flex: 5,
                        child: _buildWordArea(word),
                      ),
                      // 下半：释义/4选1（原版 rl_learnHalfBottom）
                      Expanded(
                        flex: 5,
                        child: _buildBottomArea(word),
                      ),
                      // 底部操作栏（原版 learn_review_bottom_bar）
                      _buildBottomBar(word),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// 顶部栏（原版 top_bar_container）
  Widget _buildTopBar() {
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
          Text(
            '$_done',
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
                value: _total == 0 ? 0 : _done / _total,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  /// 上半：单词 + 音标 + 发音（原版 word_container + PhoneticView）
  Widget _buildWordArea(BBWordProcess word) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                word.word,
                style: const TextStyle(
                  fontSize: AppDimens.learnMainWord,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _playWordAudio(word),
                icon: const Icon(Icons.volume_up, color: Colors.white, size: 26),
              ),
            ],
          ),
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

  /// 下半：未看答案 → 4选1；已看答案 → 释义+例句
  Widget _buildBottomArea(BBWordProcess word) {
    final examples = ExampleParser.parse(word.example);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: !_showAnswer && _choices.isNotEmpty
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
                  ..._choices.map(
                    (c) => _ChoiceOption(
                      pair: c,
                      isAnswer: c.word == word.word,
                      onTap: () {
                        _rate(c.word == word.word
                            ? RecallRating.good
                            : RecallRating.again);
                      },
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (word.interpret.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        word.interpret,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.4,
                          color: AppColors.black87,
                        ),
                      ),
                    ),
                  if (examples.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '例句',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...examples.take(3).map((ex) => _ExampleTile(example: ex)),
                  ],
                ],
              ),
            ),
    );
  }

  /// 底部操作栏（原版 learn_review_bottom_bar）
  Widget _buildBottomBar(BBWordProcess word) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Row(
        children: [
          _ReviewButton(
            label: '不认识',
            color: AppColors.errorRed,
            onTap: () => _rate(RecallRating.again),
          ),
          _ReviewButton(
            label: '模糊',
            color: AppColors.highlightOrange,
            onTap: () => _rate(RecallRating.hard),
          ),
          _ReviewButton(
            label: _showAnswer ? '认识' : '看答案',
            color: AppColors.successGreen,
            onTap: () {
              if (_showAnswer) {
                _rate(RecallRating.good);
              } else {
                setState(() => _showAnswer = true);
              }
            },
          ),
        ],
      ),
    );
  }

  /// 复习完成页
  Widget _buildReviewDone() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.successGreen, size: 72),
            const SizedBox(height: 16),
            const Text(
              '今日复习完成！',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '共复习 $_done 个单词',
              style: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.successGreen,
              ),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playWordAudio(BBWordProcess word) async {
    try {
      final player = AudioPlayer();
      await player.play(UrlSource(
        'http://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word.word)}&type=2',
      ));
    } catch (_) {}
  }
}

/// 复习按钮（复刻原版 LearnButton）
class _ReviewButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ReviewButton({
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

/// 4 选 1 选项（复刻原版 WordChoiceSelView）
class _ChoiceOption extends StatelessWidget {
  final dynamic pair;
  final bool isAnswer;
  final VoidCallback onTap;

  const _ChoiceOption({
    required this.pair,
    required this.isAnswer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        margin: const EdgeInsets.only(bottom: AppDimens.selectItemBottomMargins),
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.selectItemLrMargins),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(AppDimens.radiusNormal),
          border: Border.all(color: AppColors.dividerGrey),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isAnswer ? AppColors.successGreen : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  isAnswer ? '✓' : 'A',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                pair.interpret.toString(),
                style: const TextStyle(fontSize: 15, color: AppColors.black87),
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

/// 例句条目（复刻原版例句卡片）
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
