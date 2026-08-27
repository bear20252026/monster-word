// 复习页：壁纸沉浸 + 四选一 + 睭底操作栏
// 已接入 SkinSystem 主题
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/core_engine.dart' show WordChoicePair;
import '../features/learning/application/review_queue_reader.dart';
import '../features/learning/domain/choice_generator.dart';
import '../features/learning/presentation/review_queue_state.dart';
import '../engine/fsrs6_engine.dart' show FsrsRating;
import '../services/audio_service.dart';
import '../engine/srs_engine.dart';
import '../engine/super_memory_engine.dart';
import '../hooks/responsive.dart';
import '../models/bb_word_process.dart';
import '../models/word.dart';
import '../pages/dictionary_page.dart';
import '../state/learning_state.dart';
import '../data/wallpaper_data.dart' show WallpaperType;
import '../state/wallpaper_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/session_exit_guard.dart';

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
  int _wrongChoiceIndex = -1;
  bool _isFavorited = false;
  bool _canUndo = false;
  final List<BBWordProcess> _history = [];

  @override
  void initState() {
    super.initState();
    _initReview();
  }

  /// 初始化复习（使用 FSRS-6 到期调度）
  Future<void> _initReview() async {
    try {
      final reviewQueue = context.read<ReviewQueueState>();
      final pool = await context.read<ReviewQueueReader>().loadWords(reviewQueue.snapshot);
      final processes = pool
          .map(
            (w) => BBWordProcess(
              word: w.word,
              wordId: w.id,
              interpret: w.interpret,
              usPron: w.usPron,
              ukPron: w.ukPron,
              example: w.example,
            ),
          )
          .toList();
      _engine.init(processes);
      _total = _engine.totalNum;
      _done = 0;
      _initialized = true;
      _regenerateChoices();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[ReviewPage] init error: $e');
      _initialized = true;
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载复习数据失败: $e'),
            action: SnackBarAction(
              label: '重试',
              onPressed: () {
                _initialized = false;
                _initReview();
              },
            ),
          ),
        );
      }
    }
  }

  /// 通过共享规则生成四选一候选：释义去重、中文优先和稳定兜底与学习流程保持一致。
  void _regenerateChoices() {
    final current = _engine.currentWord();
    if (current == null) return;

    final choices = ChoiceGenerator.generate(
      correct: ChoiceCandidate(word: current.word, interpret: current.interpret),
      candidates: _engine.reviewList.map((word) => ChoiceCandidate(word: word.word, interpret: word.interpret)),
    );
    _choices = choices.map((choice) => WordChoicePair(choice.word, choice.interpret)).toList();
  }

  /// 评分（同步到 FSRS-6 算法 + Leitner 引擎）
  void _rate(RecallRating rating) {
    // 同步到 Leitner 引擎
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
    // 同步到 FSRS-6 算法（精确记忆评估）
    final fsrsRating = switch (rating) {
      RecallRating.again => FsrsRating.again,
      RecallRating.hard => FsrsRating.hard,
      RecallRating.good => FsrsRating.good,
      RecallRating.easy => FsrsRating.easy,
    };
    final currentWord = _engine.currentWord();
    if (currentWord != null) {
      context.read<LearningState>().rate(fsrsRating);
    }
    _done++;
    _showAnswer = false;
    _wrongChoiceIndex = -1;
    _regenerateChoices();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final word = _engine.currentWord();
    final skin = context.skin.colors;
    final resp = context.responsive;
    final wallpaper = context.watch<WallpaperState>().current;

    // 横屏检测
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return SessionExitGuard(
      subject: '本次复习',
      child: Scaffold(
        body: word == null
            ? _buildReviewDone()
            : Stack(
                children: [
                  // 全屏壁纸背景
                  Positioned.fill(child: _buildWallpaperBg(wallpaper, skin)),
                  // 半透明遮罩
                  Positioned.fill(child: Container(color: skin.wallpaperScrim.withValues(alpha: 0.15))),
                  SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isLandscape ? double.infinity : resp.contentMaxWidth),
                        child: isLandscape
                            ? Row(
                                children: [
                                  Expanded(child: _buildWordArea(word, skin)),
                                  Expanded(child: _buildChoiceArea(word, skin)),
                                ],
                              )
                            : Column(
                                children: [
                                  // 顶部栏
                                  _buildTopBar(skin),
                                  // 上半：单词区
                                  Expanded(flex: 4, child: _buildWordArea(word, skin)),
                                  // 下半：4选1
                                  Expanded(flex: 6, child: _buildChoiceArea(word, skin)),
                                  // 底部操作栏
                                  _buildBottomBar(skin),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildWallpaperBg(dynamic wallpaper, ThemeVars skin) {
    if (wallpaper.type == WallpaperType.image && wallpaper.assetPath != null) {
      return Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: AssetImage(wallpaper.assetPath!), fit: BoxFit.cover, onError: (_, _) {}),
        ),
      );
    }
    if (wallpaper.type == WallpaperType.gradient && wallpaper.colors != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: wallpaper.colors!,
            begin: wallpaper.begin ?? Alignment.topCenter,
            end: wallpaper.end ?? Alignment.bottomCenter,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skin.pageBg, skin.cardBg],
        ),
      ),
    );
  }

  /// 顶部栏（原版 top_bar_container）
  Widget _buildTopBar(ThemeVars skin) {
    final resp = context.responsive;
    return Container(
      height: AppSpacing.navH,
      margin: const EdgeInsets.only(top: 4),
      padding: EdgeInsets.symmetric(horizontal: resp.horizontalPadding * 0.5),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 20, color: skin.onGlassText1),
            tooltip: '返回',
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            '$_done/$_total',
            style: TextStyle(fontSize: 16 * resp.fontScale, fontWeight: FontWeight.w600, color: skin.onGlassText1),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.undo, size: 22, color: skin.onGlassText2),
            tooltip: '撤销',
            onPressed: _canUndo ? _undo : null,
          ),
          IconButton(
            icon: Icon(
              _isFavorited ? Icons.star : Icons.star_border,
              size: 22,
              color: _isFavorited ? MistralColors.accent : skin.onGlassText1,
            ),
            tooltip: '收藏',
            onPressed: _toggleFavorite,
          ),
          // abc button - 显示答案
          GestureDetector(
            onTap: _revealAnswer,
            child: Text(
              'abc',
              style: TextStyle(fontSize: 16 * resp.fontScale, fontWeight: FontWeight.w700, color: skin.onGlassText1),
            ),
          ),
          const SizedBox(width: 12),
          // 熟 button - 标记已掌握
          GestureDetector(
            onTap: _markAsKnown,
            child: Text(
              '熟',
              style: TextStyle(fontSize: 16 * resp.fontScale, fontWeight: FontWeight.w700, color: skin.onGlassText1),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.more_horiz, size: 22, color: skin.onGlassText1),
            tooltip: '更多',
            onPressed: () => _showMoreOptions(context),
          ),
        ],
      ),
    );
  }

  /// 上半：单词 + 音标 + 发音
  Widget _buildWordArea(BBWordProcess word, ThemeVars skin) {
    final resp = context.responsive;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 单词（大号粗体）
          Text(
            word.word,
            style: TextStyle(
              fontSize: 42 * resp.fontScale,
              fontWeight: FontWeight.w800,
              color: skin.onGlassText1,
              height: 1.1,
            ),
          ),
          if (word.usPron.isNotEmpty || word.ukPron.isNotEmpty) ...[
            const SizedBox(height: 10),
            // 音标行：美 🏷 /pronunciation/
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // "美" 标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: skin.glassBg.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '美',
                    style: TextStyle(
                      fontSize: 12 * resp.fontScale,
                      color: skin.onGlassText1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _playWordAudio(word),
                  child: _audioLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: skin.onGlassText2),
                        )
                      : Icon(Icons.volume_up_outlined, color: skin.onGlassText2, size: 20),
                ),
                const SizedBox(width: 6),
                Text(
                  '/${word.usPron.isNotEmpty ? word.usPron : word.ukPron}/',
                  style: TextStyle(fontSize: 15 * resp.fontScale, color: skin.onGlassText2),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // 提示文字
          Text(
            '先回想词义再选择，想不起来「看答案」',
            style: TextStyle(fontSize: 14 * resp.fontScale, color: skin.onGlassText2.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  /// 下半：4选1 选项区
  Widget _buildChoiceArea(BBWordProcess word, ThemeVars skin) {
    final resp = context.responsive;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: resp.horizontalPadding),
      child: Column(
        children: [
          const SizedBox(height: 8),
          if (_choices.isNotEmpty)
            ..._choices.map(
              (c) => _FrostedChoiceCard(
                pair: c,
                isCorrect: c.word == word.word,
                isSelectedWrong: _wrongChoiceIndex == _choices.indexOf(c),
                showAnswer: _showAnswer,
                skin: skin,
                resp: resp,
                onTap: () {
                  if (c.word == word.word) {
                    _rate(RecallRating.good);
                  } else {
                    setState(() => _wrongChoiceIndex = _choices.indexOf(c));
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) setState(() => _wrongChoiceIndex = -1);
                    });
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  /// 底部操作栏（单按钮：看答案 / 继续）
  Widget _buildBottomBar(ThemeVars skin) {
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        onTap: () {
          if (!_showAnswer) {
            setState(() => _showAnswer = true);
          } else {
            _rate(RecallRating.good);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _showAnswer ? '继续' : '看答案',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: skin.onGlassText1),
            ),
            const SizedBox(height: 6),
            // 底部彩色指示条
            Container(
              width: 24,
              height: 3,
              decoration: BoxDecoration(
                color: _showAnswer ? skin.quizCorrectText : skin.quizWrongText,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _undo() {
    if (_history.isNotEmpty && _done > 0) {
      _history.removeLast();
      _done = _done - 1;
      _showAnswer = false;
      _wrongChoiceIndex = -1;
      _regenerateChoices();
      if (mounted) setState(() {});
    }
  }

  void _toggleFavorite() {
    final current = _engine.currentWord();
    if (current != null) {
      setState(() => _isFavorited = !_isFavorited);
      // TODO: persist favorite to database
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFavorited ? '已收藏 ${current.word}' : '已取消收藏'), duration: const Duration(seconds: 1)),
      );
    }
  }

  void _revealAnswer() {
    setState(() => _showAnswer = true);
    _canUndo = true;
  }

  void _markAsKnown() {
    // 保存当前状态到历史记录（用于撤销）
    final currentWord = _engine.currentWord();
    if (currentWord != null) {
      _history.add(currentWord);
    }
    _engine.iReallyKnow();
    _done++;
    _showAnswer = false;
    _wrongChoiceIndex = -1;
    _canUndo = true;
    _regenerateChoices();
    if (mounted) setState(() {});
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.volume_up),
              title: const Text('播放发音'),
              onTap: () {
                Navigator.pop(ctx);
                final w = _engine.currentWord();
                if (w != null) _playWordAudio(w);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.pop(ctx);
                final w = _engine.currentWord();
                if (w != null) {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => DictionaryPage(
                        word: Word(
                          id: w.wordId,
                          word: w.word,
                          mainWord: w.word,
                          interpret: w.interpret,
                          usPron: w.usPron,
                          ukPron: w.ukPron,
                          example: w.example,
                          phrase: '',
                          confuse: '',
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 复习完成页
  Widget _buildReviewDone() {
    final skin = context.skin.colors;
    return Scaffold(
      backgroundColor: skin.pageBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: skin.success, size: 72),
            const SizedBox(height: 16),
            Text(
              '今日复习完成！',
              style: MistralTypography.heading3.copyWith(fontWeight: FontWeight.bold, color: skin.text1),
            ),
            const SizedBox(height: 8),
            Text('共复习 $_done 个单词', style: MistralTypography.bodySm.copyWith(color: skin.text3)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
              style: FilledButton.styleFrom(backgroundColor: skin.success),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    );
  }

  bool _audioLoading = false;

  Future<void> _playWordAudio(BBWordProcess word) async {
    if (_audioLoading) return;
    setState(() => _audioLoading = true);
    try {
      // 使用 AudioService 播放单词发音
      await sl<AudioService>().playWordAudio(word.word);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('发音加载失败，请检查网络'), duration: Duration(seconds: 2)));
      }
    } finally {
      if (mounted) setState(() => _audioLoading = false);
    }
  }
}

/// 毛玻璃选项卡片（还原原版选择卡片）
class _FrostedChoiceCard extends StatelessWidget {
  final dynamic pair;
  final bool isCorrect;
  final bool isSelectedWrong;
  final bool showAnswer;
  final ThemeVars skin;
  final AppResponsive resp;
  final VoidCallback onTap;

  const _FrostedChoiceCard({
    required this.pair,
    required this.isCorrect,
    required this.isSelectedWrong,
    required this.showAnswer,
    required this.skin,
    required this.resp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    if (isSelectedWrong) {
      bgColor = skin.quizWrongBg.withValues(alpha: 0.6);
      borderColor = skin.quizWrongBg;
    } else if (isCorrect && showAnswer) {
      bgColor = skin.quizCorrectBg.withValues(alpha: 0.6);
      borderColor = skin.quizCorrectBg;
    } else {
      bgColor = skin.glassBg.withValues(alpha: 0.25);
      borderColor = skin.glassBorder.withValues(alpha: 0.3);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(horizontal: 20 * resp.scale, vertical: 18 * resp.scale),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Text(
          pair.interpret.toString(),
          style: TextStyle(
            fontSize: 16 * resp.fontScale,
            color: skin.onGlassText1,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
