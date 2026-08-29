// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 学习页：Mistral AI 设计风格
// 流程：4选1 → 选错标红重选 → 选对标绿 → 进字典详情页 → 下一词
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/audio_playback_state.dart';
import '../../../core/engine/fsrs6_engine.dart' show FsrsRating;
import 'package:word_app/core/presentation/responsive.dart';
import '../../../core/router/route_names.dart';
import '../../../theme/skin_system.dart';

import '../../../tokens/star_gold.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/word_lookup_popup.dart';
import '../../../widgets/box_reveal.dart';
import '../../../widgets/confetti.dart';
import '../../../widgets/scratch_to_reveal.dart';
import '../../../core/router/nav_utils.dart';
import 'learning_favorites_state.dart';
import 'learning_session_state.dart';

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});
  static const routeName = '/learn';

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  Future<void> _playAudio(String word, {String? audioUrl}) async {
    final player = context.read<AudioPlaybackState>();
    if (player.isLoading) return;
    try {
      await player.playWord(word, audioUrl: audioUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('发音加载失败，请检查网络'), duration: Duration(seconds: 2)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final state = context.watch<LearningSessionState>();
    final player = context.watch<AudioPlaybackState>();
    final word = state.currentWord;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        state.exitLearning();
      },
      child: Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: word == null
            ? _CompletionScreen(
                skin: skin,
                errorCount: state.errorWords.length,
                totalAnswered: state.totalAnswered,
                durationSeconds: state.sessionDurationSeconds,
                accuracy: state.accuracy,
                onReviewErrors: state.errorWords.isEmpty
                    ? null
                    : () {
                        state.loadFromWords(state.errorWords, book: state.currentBook);
                      },
              )
            : SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isLandscape ? double.infinity : resp.contentMaxWidth),
                    child: isLandscape
                        ? Row(
                            children: [
                              Expanded(
                                child: _WordArea(
                                  word: word,
                                  skin: skin,
                                  resp: resp,
                                  audioLoading: player.isLoading && player.currentWord == word.word,
                                  onPlayAudio: _playAudio,
                                ),
                              ),
                              Expanded(
                                child: _QuizArea(word: word, state: state, skin: skin),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _TopBar(skin: skin, state: state),
                              Expanded(
                                flex: 4,
                                child: _WordArea(
                                  word: word,
                                  skin: skin,
                                  resp: resp,
                                  audioLoading: player.isLoading && player.currentWord == word.word,
                                  onPlayAudio: _playAudio,
                                ),
                              ),
                              Expanded(
                                flex: 6,
                                child: _QuizArea(word: word, state: state, skin: skin),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final SkinSystem skin;
  final LearningSessionState state;
  const _TopBar({required this.skin, required this.state});

  @override
  Widget build(BuildContext context) {
    final word = state.currentWord;
    final favorites = context.watch<LearningFavoritesState>();
    final isFav = word != null && favorites.isFavorite(word.word);
    final colors = skin.colors;

    return Container(
      height: context.design.spacing.navH,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: colors.text1,
            tooltip: '返回',
            onPressed: () => NavUtils.safePop(context),
          ),
          Text(
            '${state.currentIndex + 1}/${state.total}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.text1),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: state.total == 0 ? 0.0 : (state.currentIndex + 1) / state.total),
              duration: const Duration(milliseconds: 400),
              curve: standardCurve,
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: colors.divider,
                  valueColor: AlwaysStoppedAnimation(colors.accent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? StarGold.gold : colors.text2,
              size: 22,
            ),
            tooltip: isFav ? '取消收藏' : '收藏',
            onPressed: word == null ? null : () => favorites.toggle(word.word),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, size: 22),
            color: colors.text2,
            tooltip: '更多',
            onSelected: (value) {
              switch (value) {
                case 'skip':
                  state.rate(FsrsRating.again);
                  break;
                case 'favorite':
                  if (word != null) favorites.toggle(word.word);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'skip',
                child: ListTile(
                  leading: Icon(Icons.skip_next, size: 20),
                  title: Text('跳过当前单词'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'favorite',
                child: ListTile(
                  leading: Icon(Icons.star, size: 20),
                  title: Text('收藏/取消收藏'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletionScreen extends StatelessWidget {
  final SkinSystem skin;
  final int errorCount;
  final int totalAnswered;
  final int? durationSeconds;
  final double? accuracy;
  final VoidCallback? onReviewErrors;
  const _CompletionScreen({
    required this.skin,
    this.errorCount = 0,
    this.totalAnswered = 0,
    this.durationSeconds,
    this.accuracy,
    this.onReviewErrors,
  });

  @override
  Widget build(BuildContext context) {
    final colors = skin.colors;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.celebration, size: 80, color: colors.accent),
              const SizedBox(height: 24),
              Text(
                '🎉 今日学习完成！',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.text1),
              ),
              const SizedBox(height: 12),
              Text(
                onReviewErrors != null && errorCount > 0
                    ? '本次学习了 $totalAnswered 个单词，错了 $errorCount 个'
                    : '你已经完成了今天的所有单词，太棒了！',
                style: TextStyle(fontSize: 16, color: colors.text2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.divider),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(label: '答对率', value: accuracy == null ? '--' : '${(accuracy! * 100).round()}%', colors: colors),
                    _StatItem(label: '用时', value: durationSeconds == null ? '--' : _formatDuration(durationSeconds!), colors: colors),
                    _StatItem(label: '答错', value: '$errorCount', colors: colors),
                  ],
                ),
              ),
              if (onReviewErrors != null && errorCount > 0) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: onReviewErrors,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('复习错题'),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onGlassAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => NavUtils.goHome(context),
                  child: const Text('返回首页', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds秒';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) {
      return remainingSeconds > 0 ? '$minutes分$remainingSeconds秒' : '$minutes分钟';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes > 0 ? '$hours时$remainingMinutes分' : '$hours小时';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final dynamic colors;
  const _StatItem({required this.label, required this.value, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.text1)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: colors.text3)),
      ],
    );
  }
}

class _WordArea extends StatelessWidget {
  final dynamic word;
  final SkinSystem skin;
  final AppResponsive resp;
  final bool audioLoading;
  final Future<void> Function(String, {String? audioUrl}) onPlayAudio;
  const _WordArea({
    required this.word,
    required this.skin,
    required this.resp,
    required this.audioLoading,
    required this.onPlayAudio,
  });

  String _hintText(dynamic word) {
    if (word.hasStructuredDefinitions == true) {
      final defs = word.parsedDefinitions as List;
      if (defs.isNotEmpty) {
        final first = defs.first;
        final text = first.cnDef.isNotEmpty ? first.cnDef : first.enDef;
        if (text.isNotEmpty) {
          return text.length <= 24 ? text : '${text.substring(0, 24)}…';
        }
      }
    }
    final raw = word.cleanInterpret?.toString() ?? '';
    if (raw.isEmpty) return '这个词的意思是……';
    final clean = raw.replaceAll(RegExp(r'\\n|\s{2,}'), ' ').trim();
    return clean.length <= 24 ? clean : '${clean.substring(0, 24)}…';
  }

  @override
  Widget build(BuildContext context) {
    final colors = skin.colors;
    final resp = context.responsive;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: resp.horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                WordLookupPopup(
                  word: word.word,
                  child: Text(
                    word.word,
                    style: TextStyle(
                      fontSize: 40 * resp.fontScale,
                      fontWeight: FontWeight.w800,
                      color: colors.text1,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onPlayAudio(word.word),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: audioLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: colors.text2),
                            )
                          : Icon(Icons.volume_up_outlined, color: colors.text2, size: 28),
                    ),
                  ),
                ),
              ],
            ),
            if (word.usPron.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '/${word.usPron}/',
                style: TextStyle(fontSize: 14 * resp.fontScale, color: colors.text3),
              ),
            ],
            const SizedBox(height: 18),
            WordScratchCard(word: '刮开看提示', meaning: _hintText(word), color: colors.accent),
          ],
        ),
      ),
    );
  }
}

class _QuizArea extends StatefulWidget {
  final dynamic word;
  final LearningSessionState state;
  final SkinSystem skin;
  const _QuizArea({required this.word, required this.state, required this.skin});

  @override
  State<_QuizArea> createState() => _QuizAreaState();
}

class _QuizAreaState extends State<_QuizArea> with TickerProviderStateMixin {
  int _wrongIndex = -1;
  int _correctIndex = -1;

  late AnimationController _shakeController;
  late AnimationController _bounceController;
  late AnimationController _checkController;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _bounceController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _checkController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _confettiController = ConfettiController();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _bounceController.dispose();
    _checkController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _QuizArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.word != widget.word.word) {
      _wrongIndex = -1;
      _correctIndex = -1;
      _shakeController.reset();
      _bounceController.reset();
      _checkController.reset();
      _confettiController.reset();
    }
  }

  void _onChoice(int i) {
    if (_correctIndex >= 0) return;
    final isCorrect = widget.state.choices[i].word == widget.word.word;
    if (isCorrect) {
      setState(() {
        _correctIndex = i;
        _wrongIndex = -1;
      });
      _bounceController.forward(from: 0);
      _checkController.forward(from: 0);
      _confettiController.play();
    } else {
      setState(() => _wrongIndex = i);
      _shakeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final colors = widget.skin.colors;
    final resp = context.responsive;

    return ConfettiOverlay(
      controller: _confettiController,
      particleCount: 30,
      direction: ConfettiDirection.down,
      duration: const Duration(seconds: 2),
      colors: const [Color(0xFF006241), Color(0xFF00754A), Color(0xFFcba258), Color(0xFFFFD93D), Color(0xFF6BCB77)],
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: resp.pageMargin),
        child: Padding(
          padding: EdgeInsets.fromLTRB(resp.horizontalPadding * 0.5, 20, resp.horizontalPadding * 0.5, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _wrongIndex >= 0 ? '请再选出正确答案' : '请选择正确释义',
                style: TextStyle(fontSize: 13 * resp.fontScale, fontWeight: FontWeight.w600, color: colors.text2),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < state.choices.length && i < 4; i++)
                BoxReveal(
                  direction: BoxRevealDirection.left,
                  duration: const Duration(milliseconds: 300),
                  delay: Duration(milliseconds: 50 * i),
                  reveal: true,
                  child: _buildChoice(i),
                ),
              if (_correctIndex >= 0) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(
                        RouteNames.wordDetail,
                        arguments: {'fromLearn': true},
                      );
                    },
                    icon: Icon(Icons.arrow_forward, size: 20, color: Colors.white),
                    label: Text('查看详解', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoice(int i) {
    final choice = widget.state.choices[i];
    final isWrong = i == _wrongIndex;
    final isCorrect = i == _correctIndex;
    String interpret = '';
    if (choice.hasStructuredDefinitions) {
      final defs = choice.parsedDefinitions;
      if (defs.isNotEmpty) {
        final first = defs.first as Map<String, String>;
        final cn = first['cn'] ?? '';
        final en = first['en'] ?? '';
        interpret = cn.isNotEmpty ? cn : en;
      } else {
        interpret = choice.cleanInterpret;
      }
    } else {
      interpret = choice.cleanInterpret;
    }
    final colors = widget.skin.colors;
    final resp = context.responsive;

    Color bgColor;
    Color borderColor;
    Color textColor;
    if (isCorrect) {
      bgColor = colors.quizCorrectBg;
      borderColor = colors.quizCorrectText;
      textColor = colors.quizCorrectText;
    } else if (isWrong) {
      bgColor = colors.quizWrongBg;
      borderColor = colors.quizWrongText;
      textColor = colors.quizWrongText;
    } else {
      bgColor = colors.cardBg;
      borderColor = colors.divider;
      textColor = colors.text1;
    }

    Widget tile = GestureDetector(
      onTap: () => _onChoice(i),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 56 * resp.scale,
            margin: const EdgeInsets.only(bottom: 16),
            padding: EdgeInsets.symmetric(horizontal: 14 * resp.scale),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: isCorrect || isWrong ? 1.5 : 0.5),
              boxShadow: isCorrect || isWrong
                  ? null
                  : const [
                      BoxShadow(color: Color(0x24000000), blurRadius: 0.5, offset: Offset(0, 0)),
                      BoxShadow(color: Color(0x3D000000), blurRadius: 1, offset: Offset(0, 1)),
                    ],
            ),
            child: Center(
              child: Text(
                interpret,
                style: TextStyle(fontSize: 16 * resp.fontScale, color: textColor, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (isCorrect)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.6, end: 1.0).animate(
                  CurvedAnimation(parent: _checkController, curve: const Cubic(0.32, 2.32, 0.61, 0.27)),
                ),
                child: FadeTransition(
                  opacity: _checkController,
                  child: Icon(Icons.check_circle_outline, color: colors.quizCorrectText, size: 24),
                ),
              ),
            ),
        ],
      ),
    );

    if (isCorrect) {
      tile = ScaleTransition(scale: buildBounceAnim(_bounceController), child: tile);
    }

    if (isWrong) {
      tile = AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          final offset = computeShakeOffset(_shakeController.value, amplitude: 3.0, cycles: 1);
          return Transform.translate(offset: Offset(offset, 0), child: child);
        },
        child: tile,
      );
    }

    if (_correctIndex >= 0 && !isCorrect) {
      tile = AnimatedOpacity(
        opacity: 0.40,
        duration: const Duration(milliseconds: 200),
        curve: standardCurve,
        child: tile,
      );
    }

    return RepaintBoundary(child: tile);
  }
}
