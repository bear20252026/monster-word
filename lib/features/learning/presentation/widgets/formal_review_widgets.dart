import 'package:flutter/material.dart';

import '../../../../data/wallpaper_data.dart' show WallpaperType;
import '../../../../engine/core_engine.dart' show WordChoicePair;
import '../../../../hooks/responsive.dart';
import '../../../../models/bb_word_process.dart';
import '../../../../theme/skin_system.dart';
import '../../../../tokens/design_tokens.dart';
import '../review_session_state.dart';

/// 正式复习进行中的响应式展示容器。
///
/// 所有题目选择和会话推进均由 [ReviewSessionState] 接收；本组件只负责布局和
/// 将用户手势路由给页面提供的界面回调。
class FormalReviewSessionLayout extends StatelessWidget {
  const FormalReviewSessionLayout({
    super.key,
    required this.word,
    required this.session,
    required this.wallpaper,
    required this.isFavorite,
    required this.onBack,
    required this.onToggleFavorite,
    required this.onMarkAsKnown,
    required this.onShowMore,
    required this.onPlayAudio,
    required this.audioLoading,
  });

  final BBWordProcess word;
  final ReviewSessionState session;
  final dynamic wallpaper;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;
  final VoidCallback onMarkAsKnown;
  final VoidCallback onShowMore;
  final ValueChanged<BBWordProcess> onPlayAudio;
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
                          child: FormalReviewChoiceGrid(word: word, session: session),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        FormalReviewHeader(
                          session: session,
                          isFavorite: isFavorite,
                          onBack: onBack,
                          onToggleFavorite: onToggleFavorite,
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
                          child: FormalReviewChoiceGrid(word: word, session: session),
                        ),
                        FormalReviewAnswerAction(session: session),
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

/// 顶部进度和词条操作栏。
class FormalReviewHeader extends StatelessWidget {
  const FormalReviewHeader({
    super.key,
    required this.session,
    required this.isFavorite,
    required this.onBack,
    required this.onToggleFavorite,
    required this.onMarkAsKnown,
    required this.onShowMore,
  });

  final ReviewSessionState session;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;
  final VoidCallback onMarkAsKnown;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final responsive = context.responsive;
    return Container(
      height: AppSpacing.navH,
      margin: const EdgeInsets.only(top: 4),
      padding: EdgeInsets.symmetric(horizontal: responsive.horizontalPadding * 0.5),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 20, color: skin.onGlassText1),
            tooltip: '返回',
            onPressed: onBack,
          ),
          Text(
            '${session.done}/${session.total}',
            style: TextStyle(
              fontSize: 16 * responsive.fontScale,
              fontWeight: FontWeight.w600,
              color: skin.onGlassText1,
            ),
          ),
          IconButton(
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              size: 22,
              color: isFavorite ? MistralColors.accent : skin.onGlassText1,
            ),
            tooltip: '收藏',
            onPressed: onToggleFavorite,
          ),
          GestureDetector(
            onTap: session.revealAnswer,
            child: Text(
              'abc',
              style: TextStyle(
                fontSize: 16 * responsive.fontScale,
                fontWeight: FontWeight.w700,
                color: skin.onGlassText1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onMarkAsKnown,
            child: Text(
              '熟',
              style: TextStyle(
                fontSize: 16 * responsive.fontScale,
                fontWeight: FontWeight.w700,
                color: skin.onGlassText1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.more_horiz, size: 22, color: skin.onGlassText1),
            tooltip: '更多',
            onPressed: onShowMore,
          ),
        ],
      ),
    );
  }
}

/// 单词、音标和发音入口。
class FormalReviewWordPrompt extends StatelessWidget {
  const FormalReviewWordPrompt({super.key, required this.word, required this.audioLoading, required this.onPlayAudio});

  final BBWordProcess word;
  final bool audioLoading;
  final ValueChanged<BBWordProcess> onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final responsive = context.responsive;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            word.word,
            style: TextStyle(
              fontSize: 42 * responsive.fontScale,
              fontWeight: FontWeight.w800,
              color: skin.onGlassText1,
              height: 1.1,
            ),
          ),
          if (word.usPron.isNotEmpty || word.ukPron.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: skin.glassBg.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '美',
                    style: TextStyle(
                      fontSize: 12 * responsive.fontScale,
                      color: skin.onGlassText1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => onPlayAudio(word),
                  child: audioLoading
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
                  style: TextStyle(fontSize: 15 * responsive.fontScale, color: skin.onGlassText2),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '先回想词义再选择，想不起来「看答案」',
            style: TextStyle(fontSize: 14 * responsive.fontScale, color: skin.onGlassText2.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

/// 正式复习的四选一候选区。
class FormalReviewChoiceGrid extends StatelessWidget {
  const FormalReviewChoiceGrid({super.key, required this.word, required this.session});

  final BBWordProcess word;
  final ReviewSessionState session;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final responsive = context.responsive;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.horizontalPadding),
      child: Column(
        children: [
          const SizedBox(height: 8),
          if (session.choices.isNotEmpty)
            ...session.choices.map(
              (choice) => FormalReviewChoiceCard(
                pair: choice,
                isCorrect: choice.word == word.word,
                isSelectedWrong: session.isWrongChoiceSelected(choice.word),
                showAnswer: session.showAnswer,
                skin: skin,
                responsive: responsive,
                onTap: () => session.selectChoice(choice.word),
              ),
            ),
        ],
      ),
    );
  }
}

/// 底部“看答案 / 继续”操作栏。
class FormalReviewAnswerAction extends StatelessWidget {
  const FormalReviewAnswerAction({super.key, required this.session});

  final ReviewSessionState session;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        onTap: session.showAnswer ? session.continueWithGoodRating : session.revealAnswer,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session.showAnswer ? '继续' : '看答案',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: skin.onGlassText1),
            ),
            const SizedBox(height: 6),
            Container(
              width: 24,
              height: 3,
              decoration: BoxDecoration(
                color: session.showAnswer ? skin.quizCorrectText : skin.quizWrongText,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 正式复习加载中的统一页面。
class FormalReviewLoadingView extends StatelessWidget {
  const FormalReviewLoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// 正式复习加载失败页面。
class FormalReviewLoadErrorView extends StatelessWidget {
  const FormalReviewLoadErrorView({super.key, required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Scaffold(
      backgroundColor: skin.pageBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: skin.quizWrongText, size: 56),
              const SizedBox(height: 16),
              Text('复习数据加载失败', style: MistralTypography.heading3.copyWith(color: skin.text1)),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: MistralTypography.bodySm.copyWith(color: skin.text3),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }
}

/// 正式复习完成页面。
class FormalReviewCompleteView extends StatelessWidget {
  const FormalReviewCompleteView({super.key, required this.done, required this.onReturnHome});

  final int done;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
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
            Text('共复习 $done 个单词', style: MistralTypography.bodySm.copyWith(color: skin.text3)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onReturnHome,
              style: FilledButton.styleFrom(backgroundColor: skin.success),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 毛玻璃候选卡片。
class FormalReviewChoiceCard extends StatelessWidget {
  const FormalReviewChoiceCard({
    super.key,
    required this.pair,
    required this.isCorrect,
    required this.isSelectedWrong,
    required this.showAnswer,
    required this.skin,
    required this.responsive,
    required this.onTap,
  });

  final WordChoicePair pair;
  final bool isCorrect;
  final bool isSelectedWrong;
  final bool showAnswer;
  final ThemeVars skin;
  final AppResponsive responsive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bgColor, borderColor) = switch ((isSelectedWrong, isCorrect && showAnswer)) {
      (true, _) => (skin.quizWrongBg.withValues(alpha: 0.6), skin.quizWrongBg),
      (_, true) => (skin.quizCorrectBg.withValues(alpha: 0.6), skin.quizCorrectBg),
      _ => (skin.glassBg.withValues(alpha: 0.25), skin.glassBorder.withValues(alpha: 0.3)),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(horizontal: 20 * responsive.scale, vertical: 18 * responsive.scale),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Text(
          pair.interpret,
          style: TextStyle(
            fontSize: 16 * responsive.fontScale,
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
