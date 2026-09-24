// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 学习页：明亮简约设计风格
// 流程：4选1 → 选错标红重选 → 选对标绿 → 进字典详情页 → 下一词
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';

import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart' show FsrsRating;
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/theme/skin_system.dart';

import 'package:word_app/tokens/star_gold.dart';
import 'package:word_app/widgets/animations.dart';
import 'package:word_app/widgets/coin_fly_overlay.dart';
import 'package:word_app/widgets/coin_swallow_celebration.dart' show CoinBadge;
import 'package:word_app/features/learning/presentation/word_lookup_popup.dart';
import 'package:word_app/widgets/box_reveal.dart';
import 'package:word_app/widgets/confetti.dart';
import 'package:word_app/widgets/monster_icon.dart';
import 'package:word_app/widgets/scratch_to_reveal.dart';
import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/widgets/session_exit_guard.dart';
import 'package:word_app/features/learning/presentation/learning_favorites_state.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/features/learning/presentation/learn_completion_screen.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/effect_palette.dart';
import 'package:word_app/tokens/motion_tokens.dart';

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});
  static const routeName = RouteNames.learn;

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  /// 顶栏余额刷新节拍（金币落袋时+1，_CoinPill 按 tick 重查余额）。
  int _balanceTick = 0;

  /// 顶栏金币 pill 定位（金币飞行终点）。
  final GlobalKey _pillKey = GlobalKey();

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

    // 体验审计 P1：有学习进度时拦截返回，与「暂停并保存」承诺一致
    // （此前系统返回直接清空队列，无确认）
    return SessionExitGuard(
      subject: '本次学习',
      shouldIntercept: () => state.hasProgress,
      child: Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: word == null
            ? LearnCompletionScreen(
                skin: skin,
                errorCount: state.errorWords.length,
                totalAnswered: state.totalAnswered,
                durationSeconds: state.sessionDurationSeconds,
                accuracy: state.accuracy,
                goalAchieved: state.dailyGoalAchieved,
                todayLearned: state.todayLearned,
                dailyGoal: state.dailyGoal,
                bestCombo: state.bestCombo,
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
                    child: Column(
                      children: [
                        // 会话进度栏：竖屏/横屏共用（此前横屏分支缺失，无进度/返回/收藏）
                        _TopBar(skin: skin, state: state, pillKey: _pillKey, balanceTick: _balanceTick),
                        Expanded(
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
                                      child: _QuizArea(
                                        word: word,
                                        state: state,
                                        skin: skin,
                                        pillKey: _pillKey,
                                        onRewarded: (_) {
                                          if (mounted) setState(() => _balanceTick++);
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
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
                                      child: _QuizArea(
                                        word: word,
                                        state: state,
                                        skin: skin,
                                        pillKey: _pillKey,
                                        onRewarded: (_) {
                                          if (mounted) setState(() => _balanceTick++);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
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

  /// 金币 pill 定位＋刷新节拍（答对飞行终点，落袋刷新）。
  final GlobalKey pillKey;
  final int balanceTick;
  const _TopBar({required this.skin, required this.state, required this.pillKey, required this.balanceTick});

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
            style: MwTypography.bodyBold.copyWith(fontWeight: FontWeight.w600, color: colors.text1),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: state.total == 0 ? 0.0 : (state.currentIndex + 1) / state.total),
              duration: const Duration(milliseconds: 400),
              curve: standardCurve,
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
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
          // 金币余额 pill（答对飞行终点；无账本语境如单测时自动隐身）。
          _CoinPill(key: pillKey, tick: balanceTick),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? StarGold.gold : colors.text2, size: 22),
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

/// 顶栏金币余额 pill：金币＋余额数字，答对飞行终点。
/// 无账本语境（如单测最小装配）自动隐身，不抛 ProviderNotFound。
/// tick 变化即重查余额，数字经 AnimatedSwitcher 缩放 pop（落袋感）。
class _CoinPill extends StatelessWidget {
  final int tick;
  const _CoinPill({super.key, required this.tick});

  @override
  Widget build(BuildContext context) {
    final store = context.read<ScareCoinStore?>();
    if (store == null) return const SizedBox.shrink();
    final colors = context.skin.colors;
    return FutureBuilder<int>(
      key: ValueKey(tick),
      future: store.balance(),
      builder: (context, snap) {
        final balance = snap.data ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: ShapeDecoration(
            color: MwColors.sunshine300.withValues(alpha: 0.14),
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinBadge(size: 18),
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: MotionDurations.base,
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Text(
                  '$balance',
                  key: ValueKey('$tick-$balance'),
                  style: MwTypography.caption.copyWith(fontWeight: FontWeight.w700, color: colors.text1),
                ),
              ),
            ],
          ),
        );
      },
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
                      fontSize: AppFontSizes.hero * resp.fontScale,
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
                style: TextStyle(fontSize: AppFontSizes.bodySm * resp.fontScale, color: colors.text3),
              ),
            ],
            const SizedBox(height: 18),
            // ValueKey + resetToken 双保险：换词时强制重建/重置刮刮层，
            // 杜绝"第一词刮开后后续词自动露出提示"的泄答案 bug。
            WordScratchCard(
              key: ValueKey(word.word),
              word: '刮开看提示',
              meaning: _hintText(word),
              color: colors.accent,
              resetToken: word.word,
            ),
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

  /// 金币飞行终点（顶栏 pill 定位）。
  final GlobalKey pillKey;

  /// 落袋回调（实发币数；父级刷新余额节拍）。
  final ValueChanged<int> onRewarded;
  const _QuizArea({
    required this.word,
    required this.state,
    required this.skin,
    required this.pillKey,
    required this.onRewarded,
  });

  @override
  State<_QuizArea> createState() => _QuizAreaState();
}

class _QuizAreaState extends State<_QuizArea> with TickerProviderStateMixin {
  int _wrongIndex = -1;
  int _correctIndex = -1;

  /// 选项 tile 定位（金币飞行起点）；选项固定 4 席。
  final List<GlobalKey> _tileKeys = List<GlobalKey>.generate(4, (_) => GlobalKey());

  late AnimationController _shakeController;
  late AnimationController _bounceController;
  late AnimationController _checkController;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(duration: MotionDurations.slow, vsync: this);
    _bounceController = AnimationController(duration: MotionDurations.slow, vsync: this);
    _checkController = AnimationController(duration: MotionDurations.base, vsync: this);
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
      // 连击计入会话（错后重选不续杯，见 recordAnswer），完成页＋战报消费 bestCombo。
      widget.state.recordAnswer(true);
      _bounceController.forward(from: 0);
      _checkController.forward(from: 0);
      _confettiController.play();
      _rewardFly(i);
    } else {
      setState(() => _wrongIndex = i);
      widget.state.recordAnswer(false);
      _shakeController.forward(from: 0);
    }
  }

  static Offset? _centerOf(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  /// 答对奖励飞行：先记账（＋1，日封顶，静默失败），再从选项飞向顶栏；
  /// 无账本语境（单测最小装配）直接跳过，不抛错。
  Future<void> _rewardFly(int index) async {
    if (index < 0 || index >= _tileKeys.length) return;
    final from = _centerOf(_tileKeys[index]);
    final to = _centerOf(widget.pillKey);
    if (from == null || to == null) return;
    final store = context.read<ScareCoinStore?>();
    if (store == null) return;
    int granted = 0;
    try {
      granted = await store.grantAnswerReward();
    } catch (_) {
      return;
    }
    if (granted <= 0 || !mounted) return;
    CoinFlyOverlay.play(
      context,
      from: from,
      to: to,
      onArrive: () {
        if (!mounted) return;
        widget.onRewarded(granted);
      },
    );
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
      colors: GradientEffects.celebration,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: resp.pageMargin),
        child: Padding(
          padding: EdgeInsets.fromLTRB(resp.horizontalPadding * 0.5, 20, resp.horizontalPadding * 0.5, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 连击条：≥2 现身，≥3 火苗，≥5 怪兽探头欢呼（形态切换带缩放 pop）。
              if (widget.state.combo >= 2) ...[
                Row(
                  children: [
                    AnimatedSwitcher(
                      duration: MotionDurations.base,
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: widget.state.combo >= 5
                          ? const MonsterIcon(key: ValueKey('cheer'), size: 24)
                          : const Icon(
                              key: ValueKey('fire'),
                              Icons.local_fire_department_rounded,
                              size: 20,
                              color: StarGold.gold,
                            ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '连击 ×${widget.state.combo}',
                      style: TextStyle(
                        fontSize: AppFontSizes.bodySm * resp.fontScale,
                        fontWeight: FontWeight.w800,
                        color: colors.text1,
                      ),
                    ),
                    if (widget.state.combo >= 5)
                      Text(
                        ' 小怪兽为你欢呼！',
                        style: TextStyle(fontSize: AppFontSizes.caption * resp.fontScale, color: colors.text2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Text(
                _wrongIndex >= 0 ? '请再选出正确答案' : '请选择正确释义',
                style: TextStyle(
                  fontSize: AppFontSizes.caption * resp.fontScale,
                  fontWeight: FontWeight.w600,
                  color: colors.text2,
                ),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < state.choices.length && i < 4; i++)
                BoxReveal(
                  direction: BoxRevealDirection.left,
                  duration: MotionDurations.slow,
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
                      Navigator.of(context).pushNamed(RouteNames.wordDetail, arguments: {'fromLearn': true});
                    },
                    icon: Icon(Icons.arrow_forward, size: 20, color: AppColors.white100),
                    label: Text(
                      '查看详解',
                      style: const TextStyle(fontSize: AppFontSizes.bodyMd, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: AppColors.white100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.control)),
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
            key: _tileKeys[i],
            duration: MotionDurations.base,
            height: 56 * resp.scale,
            margin: const EdgeInsets.only(bottom: 16),
            padding: EdgeInsets.symmetric(horizontal: 14 * resp.scale),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: borderColor, width: isCorrect || isWrong ? 1.5 : 0.5),
              boxShadow: isCorrect || isWrong
                  ? null
                  : const [
                      BoxShadow(color: MwShadows.softShadow, blurRadius: 0.5, offset: Offset(0, 0)),
                      BoxShadow(color: MwShadows.liftShadow, blurRadius: 1, offset: Offset(0, 1)),
                    ],
            ),
            child: Center(
              child: Text(
                interpret,
                style: TextStyle(
                  fontSize: AppFontSizes.bodyMd * resp.fontScale,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (isCorrect)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.6,
                  end: 1.0,
                ).animate(CurvedAnimation(parent: _checkController, curve: const Cubic(0.32, 2.32, 0.61, 0.27))),
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
          // 温柔下沉：exit 家族下探 5px 即回＋轻淡，不再左右抖（去惩罚感）。
          final dip = math.sin(_shakeController.value * math.pi) * 5;
          final fade = 1 - _shakeController.value * 0.12;
          return Transform.translate(
            offset: Offset(0, dip),
            child: Opacity(opacity: fade, child: child),
          );
        },
        child: tile,
      );
    }

    if (_correctIndex >= 0 && !isCorrect) {
      tile = AnimatedOpacity(opacity: 0.40, duration: MotionDurations.base, curve: standardCurve, child: tile);
    }

    return RepaintBoundary(child: tile);
  }
}
