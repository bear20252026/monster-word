// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 学习页：Mistral AI 设计风格
// 流程：4选1 → 选错标红重选 → 选对标绿 → 进字典详情页 → 下一词
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/srs_engine.dart';
import '../hooks/responsive.dart';
import '../state/learning_state.dart';
import '../data/wallpaper_data.dart';
import '../state/wallpaper_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/animations.dart';
import '../widgets/word_lookup_popup.dart';

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});
  static const routeName = '/learn';

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final state = context.watch<LearningState>();
    final word = state.currentWord;
    final wallpaper = context.watch<WallpaperState>().current;

    return Scaffold(
      body: word == null
          ? const Center(child: Text('暂无单词'))
          : Stack(
              children: [
                // 全屏壁纸背景
                Positioned.fill(
                  child: _buildWallpaperBg(wallpaper, skin),
                ),
                // 半透明遮罩
                Positioned.fill(
                  child: Container(color: Colors.black.withOpacity(0.15)),
                ),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: resp.contentWidth),
                      child: Column(
                        children: [
                          _TopBar(skin: skin, state: state),
                          Expanded(flex: 4, child: _WordArea(word: word, skin: skin, resp: resp)),
                          Expanded(flex: 6, child: _QuizArea(word: word, state: state)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWallpaperBg(dynamic wallpaper, SkinSystem skin) {
    if (wallpaper.type == WallpaperType.image && wallpaper.assetPath != null) {
      return Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(wallpaper.assetPath!),
            fit: BoxFit.cover,
            onError: (_, __) {},
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
          colors: [skin.colors.pageBg, skin.colors.cardBg],
        ),
      ),
    );
  }
}

/// 顶部导航栏
class _TopBar extends StatelessWidget {
  final SkinSystem skin;
  final LearningState state;
  const _TopBar({required this.skin, required this.state});

  @override
  Widget build(BuildContext context) {
    final word = state.currentWord;
    final isFav = word != null && state.isFavorite(word.word);

    return Container(
      height: AppSpacing.navH,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: Colors.white,
            onPressed: () => Navigator.pop(context),
          ),
          Text('${state.currentIndex + 1}/${state.total}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(width: 8),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                end: state.total == 0 ? 0.0 : (state.currentIndex + 1) / state.total,
              ),
              duration: const Duration(milliseconds: 400),
              curve: standardCurve,
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 3,
                  backgroundColor: Colors.white30,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? Colors.amber : Colors.white70,
              size: 22,
            ),
            tooltip: isFav ? '取消收藏' : '收藏',
            onPressed: word == null
                ? null
                : () => state.toggleFavorite(word.word),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 22),
            color: Colors.white70,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

/// 上半：单词 + 音标 + 发音按钮
class _WordArea extends StatelessWidget {
  final dynamic word;
  final SkinSystem skin;
  final AppResponsive resp;
  const _WordArea({required this.word, required this.skin, required this.resp});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(left: 60, right: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                WordLookupPopup(
                  word: word.word,
                  child: Text(word.word,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    )),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    try {
                      final player = AudioPlayer();
                      await player.play(UrlSource(
                        'http://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word.word)}&type=2'));
                    } catch (_) {}
                  },
                  child: const Icon(Icons.volume_up_outlined, color: Colors.white70, size: 28),
                ),
              ],
            ),
            if (word.usPron.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('/${word.usPron}/',
                style: const TextStyle(fontSize: 14, color: Colors.white60)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 下半：4选1 选错标红重选，选对标绿进字典详情页
class _QuizArea extends StatefulWidget {
  final dynamic word;
  final LearningState state;
  const _QuizArea({required this.word, required this.state});

  @override
  State<_QuizArea> createState() => _QuizAreaState();
}

class _QuizAreaState extends State<_QuizArea> with TickerProviderStateMixin {
  int _wrongIndex = -1; // -1=未选错

  // Shake animation (wrong answer feedback)
  late AnimationController _shakeController;

  // Bounce animation (correct answer feedback)
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _QuizArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.word != widget.word.word) {
      _wrongIndex = -1;
      _shakeController.reset();
      _bounceController.reset();
    }
  }

  void _onChoice(int i) {
    final isCorrect = widget.state.choices[i].word == widget.word.word;
    if (isCorrect) {
      // 选对：评分 + 弹跳反馈，跳转字典详情页
      widget.state.rate(RecallRating.good);
      _bounceController.forward(from: 0);
      setState(() {});
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) Navigator.pushNamed(context, '/word_detail');
      });
    } else {
      // 选错：标红 + 抖动反馈，继续重选
      setState(() => _wrongIndex = i);
      _shakeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.responsive.pageMargin),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_wrongIndex >= 0 ? '请再选出正确答案' : '请选择正确释义',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white60,
              )),
            const SizedBox(height: 12),
            for (int i = 0; i < state.choices.length && i < 4; i++)
              _buildChoice(i),
          ],
        ),
      ),
    );
  }

  Widget _buildChoice(int i) {
    final choice = widget.state.choices[i];
    final isWrong = i == _wrongIndex;
    final interpret = choice.interpret.toString();

    Color bgColor;
    Color borderColor;
    if (isWrong) {
      bgColor = const Color(0xFFE8A0A0).withOpacity(0.6);
      borderColor = const Color(0xFFE8A0A0);
    } else {
      bgColor = Colors.white.withOpacity(0.25);
      borderColor = Colors.white.withOpacity(0.3);
    }

    Widget tile = GestureDetector(
      onTap: () => _onChoice(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Center(
          child: Text(interpret,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );

    // Wrap wrong choice with shake animation
    if (isWrong) {
      tile = ShakeWidget(controller: _shakeController, child: tile);
    }

    return tile;
  }
}
