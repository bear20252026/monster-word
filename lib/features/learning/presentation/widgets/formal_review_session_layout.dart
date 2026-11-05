import 'package:word_app/tokens/design_tokens.dart';
import 'package:flutter/material.dart';

import 'package:word_app/theme/wallpaper_data.dart' show WallpaperType;
import 'package:word_app/core/engine/core_engine.dart' show WordChoicePair;
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/models/mw_word_process.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/features/learning/presentation/widgets/boss_siege_header.dart';
import 'package:word_app/features/learning/presentation/widgets/formal_review_header.dart';
import 'package:word_app/features/learning/presentation/widgets/formal_review_question.dart';

/// 正式复习进行中的响应式展示容器。
///
/// 本组件只接收已经准备好的展示数据和用户动作回调，不读取 Provider，
/// 也不依赖正式复习的会话状态实现。
class FormalReviewSessionLayout extends StatelessWidget {
  const FormalReviewSessionLayout({
    super.key,
    required this.word,
    required this.choices,
    required this.done,
    required this.total,
    this.bossActive = false,
    this.bossIntroPending = false,
    this.bossShieldSegments = 0,
    this.bossShieldCapacity = 0,
    this.bossStepLabel = '',
    this.onBossIntroFinished,
    required this.selectedWrongChoice,
    required this.correctRevealed,
    required this.showAnswer,
    required this.wallpaper,
    required this.isFavorite,
    required this.onBack,
    required this.onToggleFavorite,
    required this.onMarkAsKnown,
    required this.onShowMore,
    required this.onPlayAudio,
    required this.onSelectChoice,
    required this.onRevealAnswer,
    required this.onContinueWithGoodRating,
    required this.audioLoading,
  });

  final MwWordProcess word;
  final List<WordChoicePair> choices;
  final int done;
  final int total;

  /// 头目是否登场（协调层由开局冻结的到期数判定，展示层只吃结果）。
  final bool bossActive;

  /// 当日首次入场动画播完前冻结答题（约 450ms；reduce-motion 下立即结束）。
  final bool bossIntroPending;

  /// 已裂开的护盾段数 / 本局护盾总段数；协调层用纯函数算好传入。
  final int bossShieldSegments;
  final int bossShieldCapacity;

  /// 「第 x / N 步 · 还剩 M 步」；协调层算好传入，展示层不自造口径。
  final String bossStepLabel;

  /// 入场动画结束回调（协调层据此解除答题冻结）。
  final VoidCallback? onBossIntroFinished;
  final String? selectedWrongChoice;

  /// 本题已答对（反馈驻留窗口内）：卡片变绿 + 对勾 + 彩带。
  final bool correctRevealed;
  final bool showAnswer;
  final dynamic wallpaper;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;
  final VoidCallback onMarkAsKnown;
  final VoidCallback onShowMore;
  final ValueChanged<MwWordProcess> onPlayAudio;
  final ValueChanged<String> onSelectChoice;
  final VoidCallback onRevealAnswer;
  final VoidCallback onContinueWithGoodRating;
  final bool audioLoading;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final responsive = context.responsive;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Stack(
      children: [
        Positioned.fill(
          child: FormalReviewWallpaper(wallpaper: wallpaper, skin: skin),
        ),
        Positioned.fill(
          child: Container(color: skin.wallpaperScrim.withValues(alpha: AppAlphas.o15)),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isLandscape ? double.infinity : responsive.contentMaxWidth),
              child: Column(
                children: [
                  // 进度与操作栏：竖屏/横屏共用（此前横屏缺失，无进度/返回/看答案）
                  FormalReviewHeader(
                    done: done,
                    total: total,
                    isFavorite: isFavorite,
                    onBack: onBack,
                    onToggleFavorite: onToggleFavorite,
                    onRevealAnswer: onRevealAnswer,
                    onMarkAsKnown: onMarkAsKnown,
                    onShowMore: onShowMore,
                  ),
                  // 围城条带：把「还剩几只捣蛋兽」画在进度条下面，答掉一题少一只。
                  BossSiegeHeader(
                    done: done,
                    total: total,
                    bossActive: bossActive,
                    bossIntroPending: bossIntroPending,
                    shieldSegments: bossShieldSegments,
                    shieldCapacity: bossShieldCapacity,
                    stepLabel: bossStepLabel,
                    onIntroFinished: onBossIntroFinished,
                  ),
                  // 入场动画期间冻结答题（约 450ms），避免用户在头目还没站好时就作答。
                  Expanded(
                    child: IgnorePointer(
                      ignoring: bossIntroPending,
                      child: isLandscape
                          ? Row(
                              children: [
                                Expanded(
                                  child: FormalReviewWordPrompt(
                                    word: word,
                                    audioLoading: audioLoading,
                                    onPlayAudio: onPlayAudio,
                                  ),
                                ),
                                Expanded(
                                  child: FormalReviewChoiceGrid(
                                    word: word,
                                    choices: choices,
                                    selectedWrongChoice: selectedWrongChoice,
                                    correctRevealed: correctRevealed,
                                    showAnswer: showAnswer,
                                    onSelectChoice: onSelectChoice,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: FormalReviewWordPrompt(
                                    word: word,
                                    audioLoading: audioLoading,
                                    onPlayAudio: onPlayAudio,
                                  ),
                                ),
                                Expanded(
                                  flex: 6,
                                  child: FormalReviewChoiceGrid(
                                    word: word,
                                    choices: choices,
                                    selectedWrongChoice: selectedWrongChoice,
                                    correctRevealed: correctRevealed,
                                    showAnswer: showAnswer,
                                    onSelectChoice: onSelectChoice,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  IgnorePointer(
                    ignoring: bossIntroPending,
                    child: FormalReviewAnswerAction(
                      showAnswer: showAnswer,
                      onRevealAnswer: onRevealAnswer,
                      onContinueWithGoodRating: onContinueWithGoodRating,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 正式复习背景。
class FormalReviewWallpaper extends StatelessWidget {
  const FormalReviewWallpaper({super.key, required this.wallpaper, required this.skin});

  final dynamic wallpaper;
  final ThemeVars skin;

  @override
  Widget build(BuildContext context) {
    if (wallpaper.type == WallpaperType.image && wallpaper.assetPath != null) {
      return Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: ResizeImage(AssetImage(wallpaper.assetPath!), width: 1920), // MEM：限制解码位图，避免原图像素常驻内存
            fit: BoxFit.cover,
            onError: (e, s) {},
          ),
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
}
