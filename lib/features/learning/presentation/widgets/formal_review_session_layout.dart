import 'package:flutter/material.dart';

import 'package:word_app/core/infrastructure/wallpaper_data.dart' show WallpaperType;
import 'package:word_app/core/engine/core_engine.dart' show WordChoicePair;
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/models/bb_word_process.dart';
import 'package:word_app/theme/skin_system.dart';
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
    required this.selectedWrongChoice,
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

  final BBWordProcess word;
  final List<WordChoicePair> choices;
  final int done;
  final int total;
  final String? selectedWrongChoice;
  final bool showAnswer;
  final dynamic wallpaper;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;
  final VoidCallback onMarkAsKnown;
  final VoidCallback onShowMore;
  final ValueChanged<BBWordProcess> onPlayAudio;
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
        Positioned.fill(child: Container(color: skin.wallpaperScrim.withValues(alpha: 0.15))),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isLandscape ? double.infinity : responsive.contentMaxWidth),
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
                            showAnswer: showAnswer,
                            onSelectChoice: onSelectChoice,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
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
                            showAnswer: showAnswer,
                            onSelectChoice: onSelectChoice,
                          ),
                        ),
                        FormalReviewAnswerAction(
                          showAnswer: showAnswer,
                          onRevealAnswer: onRevealAnswer,
                          onContinueWithGoodRating: onContinueWithGoodRating,
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
}
