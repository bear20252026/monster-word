// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 学习页：Mistral AI 设计风格
// 流程：4选1 → 选错标红重选 → 选对标绿 → 进字典详情页 → 下一词
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/fsrs5_engine.dart';
import '../hooks/responsive.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../tokens/star_gold.dart';
import '../widgets/animations.dart';
import '../widgets/word_lookup_popup.dart';
import '../widgets/box_reveal.dart';
import '../widgets/confetti.dart';
import '../widgets/scratch_to_reveal.dart';

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});
  static const routeName = '/learn';

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  bool _audioLoading = false;

  Future<void> _playAudio(String word) async {
    if (_audioLoading) return;
    setState(() => _audioLoading = true);
    try {
      final player = AudioPlayer();
      await player.play(UrlSource(
        'http://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word)}&type=2'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发音加载失败，请检查网络'),
            duration: Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _audioLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final state = context.watch<LearningState>();
    final word = state.currentWord;

    return Scaffold(
      backgroundColor: skin.colors.pageBg, // 奶油画布（batch4c: 壁纸→cream canvas）
      body: word == null
          ? Center(child: Text('暂无单词', style: TextStyle(color: skin.colors.text2)))
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: resp.contentMaxWidth),
                  child: Column(
                    children: [
                      _TopBar(skin: skin, state: state),
                      Expanded(flex: 4, child: _WordArea(
                        word: word, skin: skin, resp: resp,
                        audioLoading: _audioLoading,
                        onPlayAudio: _playAudio,
                      )),
                      Expanded(flex: 6, child: _QuizArea(word: word, state: state, skin: skin)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// 顶部导航栏（batch4c: 白色→token 颜色）
class _TopBar extends StatelessWidget {
  final SkinSystem skin;
  final LearningState state;
  const _TopBar({required this.skin, required this.state});

  @override
  Widget build(BuildContext context) {
    final word = state.currentWord;
    final isFav = word != null && state.isFavorite(word.word);
    final colors = skin.colors;

    return Container(
      height: AppSpacing.navH,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: colors.text1,
            onPressed: () => Navigator.pop(context),
          ),
          Text('${state.currentIndex + 1}/${state.total}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.text1)),
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
              color: isFav ? StarGold.gold : colors.text2, // 金色仅收藏态
              size: 22,
            ),
            tooltip: isFav ? '取消收藏' : '收藏',
            onPressed: word == null
                ? null
                : () => state.toggleFavorite(word.word),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 22),
            color: colors.text2,
            tooltip: '更多',
            onPressed: () {
              // 更多操作菜单
            },
          ),
        ],
      ),
    );
  }
}

/// 上半：单词 + 音标 + 发音按钮（batch4c: 白色→token 颜色）
class _WordArea extends StatelessWidget {
  final dynamic word;
  final SkinSystem skin;
  final AppResponsive resp;
  final bool audioLoading;
  final Future<void> Function(String) onPlayAudio;
  const _WordArea({
    required this.word,
    required this.skin,
    required this.resp,
    required this.audioLoading,
    required this.onPlayAudio,
  });

  /// 词义提示（刮开可见）：截取释义前 24 字，避免直接泄露完整答案
  String _hintText(dynamic word) {
    final raw = word.interpret?.toString() ?? '';
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
                  child: Text(word.word,
                    style: TextStyle(
                      fontSize: 40 * resp.fontScale,
                      fontWeight: FontWeight.w800,
                      color: colors.text1,
                      height: 1.1,
                    )),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onPlayAudio(word.word),
                  child: SizedBox(
                    width: 44, height: 44,
                    child: Center(
                      child: audioLoading
                          ? SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: colors.text2))
                          : Icon(Icons.volume_up_outlined, color: colors.text2, size: 28),
                    ),
                  ),
                ),
              ],
            ),
            if (word.usPron.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('/${word.usPron}/',
                style: TextStyle(
                  fontSize: 14 * resp.fontScale,
                  color: colors.text3,
                )),
            ],
            // 刮刮揭示：刮开查看词义提示（scratch-to-reveal 微交互）
            const SizedBox(height: 18),
            WordScratchCard(
              word: '刮开看提示',
              meaning: _hintText(word),
              color: colors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

/// 下半：4选1 选错标红重选，选对标绿进字典详情页（batch4c: 星巴克样式）
class _QuizArea extends StatefulWidget {
  final dynamic word;
  final LearningState state;
  final SkinSystem skin;
  const _QuizArea({required this.word, required this.state, required this.skin});

  @override
  State<_QuizArea> createState() => _QuizAreaState();
}

class _QuizAreaState extends State<_QuizArea> with TickerProviderStateMixin {
  int _wrongIndex = -1; // -1=未选错
  int _correctIndex = -1; // -1=未答对（P4 guard + P1 绿色确认态）

  // Shake animation (wrong answer feedback)
  late AnimationController _shakeController;

  // Bounce animation (correct answer feedback)
  late AnimationController _bounceController;

  // P2: 对勾 springPop 控制器
  late AnimationController _checkController;

  // Confetti 控制器（答对时庆祝彩带）
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300), // P3: motion_spec slow 档
      vsync: this,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _checkController = AnimationController(
      duration: const Duration(milliseconds: 200), // base 档
      vsync: this,
    );

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
    // --- P4: 防重复点击 guard ---
    if (_correctIndex >= 0) return;
    final isCorrect = widget.state.choices[i].word == widget.word.word;
    if (isCorrect) {
      // P1b+P2b: 记录答对索引，驱动绿色确认态 + 弹跳 + 对勾
      widget.state.rate(FsrsRating.good);
      setState(() => _correctIndex = i);
      _bounceController.forward(from: 0);
      _checkController.forward(from: 0);
      // 触发彩带庆祝效果
      _confettiController.play();
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
    final colors = widget.skin.colors;
    final resp = context.responsive;

    return ConfettiOverlay(
      controller: _confettiController,
      particleCount: 30,
      direction: ConfettiDirection.down,
      duration: const Duration(seconds: 2),
      colors: const [
        Color(0xFF006241),
        Color(0xFF00754A),
        Color(0xFFcba258),
        Color(0xFFFFD93D),
        Color(0xFF6BCB77),
      ],
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: resp.pageMargin),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            resp.horizontalPadding * 0.5,
            20,
            resp.horizontalPadding * 0.5,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_wrongIndex >= 0 ? '请再选出正确答案' : '请选择正确释义',
                style: TextStyle(
                  fontSize: 13 * resp.fontScale,
                  fontWeight: FontWeight.w600,
                  color: colors.text2,
                )),
              const SizedBox(height: 12),
              for (int i = 0; i < state.choices.length && i < 4; i++)
                BoxReveal(
                  direction: BoxRevealDirection.left,
                  duration: const Duration(milliseconds: 300),
                  delay: Duration(milliseconds: 50 * i),
                  reveal: true,
                  child: _buildChoice(i),
                ),
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
    final interpret = choice.interpret.toString();
    final colors = widget.skin.colors;
    final resp = context.responsive;

    // batch4c: 三态颜色使用 ThemeVars token
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
            margin: const EdgeInsets.only(bottom: 16), // P5: 触控审计 P0 间距
            padding: EdgeInsets.symmetric(horizontal: 14 * resp.scale),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12), // batch4c: 12px 圆角（ContentCard 规格）
              border: Border.all(color: borderColor, width: isCorrect || isWrong ? 1.5 : 0.5),
              // batch4c: ContentCard 双层低透明度阴影
              boxShadow: isCorrect || isWrong
                  ? null // 答对/答错态不加阴影，靠颜色区分
                  : const [
                      BoxShadow(color: Color(0x24000000), blurRadius: 0.5, offset: Offset(0, 0)),
                      BoxShadow(color: Color(0x3D000000), blurRadius: 1, offset: Offset(0, 1)),
                    ],
            ),
            child: Center(
              child: Text(interpret,
                style: TextStyle(
                  fontSize: 16 * resp.fontScale,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ),
          // P2c: 对勾图标 springPop 弹入
          if (isCorrect)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.6, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _checkController,
                    curve: const Cubic(0.32, 2.32, 0.61, 0.27), // springPop
                  ),
                ),
                child: FadeTransition(
                  opacity: _checkController,
                  child: Icon(
                    Icons.check_circle_outline,
                    color: colors.quizCorrectText,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // P1e: 答对项接入 BounceWidget
    if (isCorrect) {
      tile = ScaleTransition(
        scale: buildBounceAnim(_bounceController),
        child: tile,
      );
    }

    // P3c: 收敛抖动 ±3px/300ms 单周期（AnimatedBuilder 替代 ShakeWidget）
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

    // P7: 答对后其余选项降权 0.40
    if (_correctIndex >= 0 && !isCorrect) {
      tile = AnimatedOpacity(
        opacity: 0.40,
        duration: const Duration(milliseconds: 200),
        curve: standardCurve,
        child: tile,
      );
    }

    // 动画性能优化：RepaintBoundary 隔离重绘区域
    return RepaintBoundary(child: tile);
  }
}
