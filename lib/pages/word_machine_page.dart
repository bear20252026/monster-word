// 由 Claude 团队生成 | Monster Word App

// 不背单词机 BBDC-Dot-One：Game Boy 风格复古学习界面
// 像素风屏幕 + 单词展示 + 4选1测验 + D-pad 交互
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/fsrs6_engine.dart' show FsrsRating;
import '../core/audio/audio_playback_state.dart';
import '../core/router/nav_utils.dart';
import '../data/example_parser.dart';
import '../hooks/responsive.dart';
import '../models/word.dart';
import '../player/audio_players.dart' show playWordAudio;
import '../features/learning/presentation/learning_session_state.dart';
import '../tokens/gameboy.dart';
import '../widgets/session_exit_guard.dart';
import '../widgets/text_generate_effect.dart';
import '../widgets/word_root_tab.dart';
import '../widgets/box_reveal.dart';

/// 不背单词机页面
class WordMachinePage extends StatefulWidget {
  const WordMachinePage({super.key});
  static const routeName = '/word_machine';

  @override
  State<WordMachinePage> createState() => _WordMachinePageState();
}

class _WordMachinePageState extends State<WordMachinePage> with TickerProviderStateMixin {
  int _selectedChoice = -1;
  bool _showResult = false;
  bool _isCorrect = false;
  int _score = 0;
  int _streak = 0;
  String _statusText = 'PRESS START';
  bool _started = false;
  bool _showWordDetails = false;

  late AnimationController _blinkController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  // 音频播放状态订阅（保留用于取消之前的播放）

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);

    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _shakeAnimation = Tween<double>(
      begin: -4,
      end: 4,
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  /// 切换到上一个单词
  void _previousWord() {
    final state = context.read<LearningSessionState>();
    if (state.currentIndex > 0) {
      state.jumpTo(state.currentIndex - 1);
      setState(() {
        _selectedChoice = -1;
        _showResult = false;
        _showWordDetails = false;
        _statusText = 'WORD ${state.currentIndex + 1}';
      });
    }
  }

  /// 切换到下一个单词
  void _nextWordManual() {
    final state = context.read<LearningSessionState>();
    if (state.currentIndex < state.total - 1) {
      state.jumpTo(state.currentIndex + 1);
      setState(() {
        _selectedChoice = -1;
        _showResult = false;
        _showWordDetails = false;
        _statusText = 'WORD ${state.currentIndex + 1}';
      });
    }
  }

  void _startGame() {
    setState(() {
      _started = true;
      _score = 0;
      _streak = 0;
      _selectedChoice = -1;
      _showResult = false;
      _statusText = 'GO!';
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _statusText = '');
    });
  }

  void _onChoice(int index) {
    if (_showResult) return;

    final state = context.read<LearningSessionState>();
    final word = state.currentWord;
    if (word == null) return;

    final choices = state.choices;
    final isCorrect = choices[index].word == word.word;

    setState(() {
      _selectedChoice = index;
      _showResult = true;
      _isCorrect = isCorrect;
    });

    if (isCorrect) {
      setState(() {
        _score += 100 + _streak * 10;
        _streak++;
        _statusText = 'CORRECT! +${100 + (_streak - 1) * 10}';
      });
      state.rate(FsrsRating.good);

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _nextWord();
        }
      });
    } else {
      setState(() {
        _streak = 0;
        _statusText = 'WRONG!';
      });
      _shakeController.forward().then((_) => _shakeController.reset());
      state.rate(FsrsRating.again);

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            _selectedChoice = -1;
            _showResult = false;
            _statusText = '';
          });
        }
      });
    }
  }

  void _nextWord() {
    final state = context.read<LearningSessionState>();
    setState(() {
      _selectedChoice = -1;
      _showResult = false;
      _statusText = '';
    });
    state.next();
  }

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;

    return SessionExitGuard(
      subject: '单词机',
      shouldIntercept: () => context.read<LearningSessionState>().hasProgress,
      child: Scaffold(
        backgroundColor: GameBoyPalette.pageBackdrop,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: min(400, resp.contentWidth)),
              child: _buildConsole(),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建单词机外壳
  Widget _buildConsole() {
    return Container(
      decoration: BoxDecoration(
        color: GameBoyPalette.bodyGray,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: GameBoyPalette.shadowBlack.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部品牌栏
          _buildBrandBar(),
          // 屏幕区域
          _buildScreen(),
          // 中间装饰线
          Container(height: 3, margin: const EdgeInsets.symmetric(horizontal: 32), color: GameBoyPalette.bodyDark),
          const SizedBox(height: 16),
          // 按钮区域
          _buildControls(),
          const SizedBox(height: 20),
          // 底部扬声器格栅
          _buildSpeakerGrill(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 品牌栏
  Widget _buildBrandBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          // 电源指示灯
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _started ? GameBoyPalette.powerOn : GameBoyPalette.powerOff,
              shape: BoxShape.circle,
              boxShadow: _started ? [BoxShadow(color: GameBoyPalette.powerOnGlow, blurRadius: 6)] : null,
            ),
          ),
          const SizedBox(width: 12),
          // 品牌名
          const Text(
            'BBDC',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: GameBoyPalette.bodyDark,
              letterSpacing: 3,
            ),
          ),
          const Spacer(),
          // Dot-One 标识
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: GameBoyPalette.bodyDark, borderRadius: BorderRadius.circular(4)),
            child: const Text(
              'Dot-One',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: GameBoyPalette.bodyGray,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 屏幕区域
  Widget _buildScreen() {
    return AnimatedBuilder(
      listenable: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(offset: Offset(_shakeAnimation.value, 0), child: child);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: GameBoyPalette.screenBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: GameBoyPalette.bodyDark, width: 3),
          boxShadow: [
            BoxShadow(
              color: GameBoyPalette.shadowBlack.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(height: 320, child: _started ? _buildGameScreen() : _buildStartScreen()),
        ),
      ),
    );
  }

  /// 开始画面
  Widget _buildStartScreen() {
    return Container(
      color: GameBoyPalette.screenBg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 像素 Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: GameBoyPalette.screenDark, borderRadius: BorderRadius.circular(4)),
            child: const Center(
              child: Text(
                'BB',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: GameBoyPalette.screenLight,
                  letterSpacing: -2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '不背单词机',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: GameBoyPalette.screenDark,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'BBDC-Dot-One',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: GameBoyPalette.screenMid, letterSpacing: 1),
          ),
          const SizedBox(height: 24),
          // 闪烁 PRESS START
          FadeTransition(
            opacity: _blinkController.drive(Tween<double>(begin: 1.0, end: 0.0)),
            child: const Text(
              'PRESS START',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: GameBoyPalette.screenDark,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 版本号
          const Text(
            'v1.0.0',
            style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: GameBoyPalette.screenMid),
          ),
        ],
      ),
    );
  }

  /// 游戏画面
  Widget _buildGameScreen() {
    final state = context.watch<LearningSessionState>();
    final word = state.currentWord;

    if (word == null) {
      return Container(
        color: GameBoyPalette.screenBg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'CLEAR!',
                style: TextStyle(fontFamily: 'monospace', fontSize: 16, color: GameBoyPalette.screenDark),
              ),
              const SizedBox(height: 8),
              const Text(
                '今日学习完成',
                style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: GameBoyPalette.screenMid),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => NavUtils.goHome(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: GameBoyPalette.screenDark, borderRadius: BorderRadius.circular(4)),
                  child: const Text(
                    '返回首页',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: GameBoyPalette.screenBg),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: GameBoyPalette.screenBg,
      child: Column(
        children: [
          // 状态栏（分数 + 连击）
          _buildStatusBar(),
          // 单词展示
          _buildWordDisplay(word),
          // 单词详情面板（可展开/收起）
          _buildWordDetails(),
          // 释义区域
          _buildMeaningArea(word),
          // 4 个选项
          Expanded(child: _buildChoiceGrid(state)),
          // 底部状态文字
          if (_statusText.isNotEmpty) _buildStatusText(),
        ],
      ),
    );
  }

  /// 状态栏
  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(color: GameBoyPalette.screenDark),
      child: Row(
        children: [
          Text(
            'SCORE: $_score',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: GameBoyPalette.screenLight,
            ),
          ),
          const Spacer(),
          Text(
            'STREAK: $_streak',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _streak > 0 ? GameBoyPalette.screenLight : GameBoyPalette.screenMid,
            ),
          ),
        ],
      ),
    );
  }

  /// 单词展示
  Widget _buildWordDisplay(dynamic word) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Column(
        children: [
          TextGenerateEffect(
            text: word.word,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: GameBoyPalette.screenDark,
              letterSpacing: 2,
            ),
            duration: const Duration(milliseconds: 500),
          ),
          if (word.usPron.isNotEmpty)
            Text(
              '/${word.usPron}/',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: GameBoyPalette.screenMid),
            ),
        ],
      ),
    );
  }

  /// 释义区域
  Widget _buildMeaningArea(dynamic word) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: const Text(
        'Choose the correct meaning:',
        style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: GameBoyPalette.screenMid),
      ),
    );
  }

  /// 4 个选项
  Widget _buildChoiceGrid(LearningSessionState state) {
    final choices = state.choices;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 2.2,
        ),
        itemCount: choices.length.clamp(0, 4),
        itemBuilder: (context, i) => _buildChoiceButton(i, choices[i], state),
      ),
    );
  }

  /// 单个选项按钮
  Widget _buildChoiceButton(int index, dynamic choice, LearningSessionState state) {
    final word = state.currentWord;
    final isCorrectChoice = choice.word == word?.word;
    final isSelected = _selectedChoice == index;

    Color bgColor;
    Color textColor;
    if (_showResult && isCorrectChoice) {
      bgColor = GameBoyPalette.screenDark;
      textColor = GameBoyPalette.screenLight;
    } else if (_showResult && isSelected && !isCorrectChoice) {
      bgColor = GameBoyPalette.errorBg;
      textColor = GameBoyPalette.errorFg;
    } else {
      bgColor = GameBoyPalette.screenMid;
      textColor = GameBoyPalette.screenLight;
    }

    return GestureDetector(
      onTap: () => _onChoice(index),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? GameBoyPalette.screenDark : GameBoyPalette.borderTransparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            choice.interpret.toString().split('；').first,
            style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  /// 底部状态文字
  Widget _buildStatusText() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: GameBoyPalette.screenDark,
      child: Center(
        child: Text(
          _statusText,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: _isCorrect ? GameBoyPalette.screenLight : GameBoyPalette.errorFg,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  /// 播放发音
  void _playPronunciation() {
    final state = context.read<LearningSessionState>();
    final word = state.currentWord;
    if (word == null) return;
    // 使用 TTS 或在线音频播放
    _playAudio(word.word);
  }

  /// 播放单词音频（使用 PhoneticAudioPlayer，带缓存）
  Future<void> _playAudio(String wordText) async {
    try {
      await playWordAudio(wordText);
    } catch (e) {
      debugPrint('Audio playback error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('🔊 $wordText'), duration: const Duration(seconds: 1)));
      }
    }
  }

  /// 构建单词详情面板（BoxReveal 动画展开/收起）
  Widget _buildWordDetails() {
    final state = context.read<LearningSessionState>();
    final word = state.currentWord;
    if (word == null) return const SizedBox.shrink();

    final meaningText = word.hasStructuredDefinitions ? word.formattedDefinitions : word.interpret;

    return BoxReveal(
      direction: BoxRevealDirection.top,
      duration: const Duration(milliseconds: 350),
      reveal: _showWordDetails,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: GameBoyPalette.screenDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: GameBoyPalette.screenMid),
        ),
        child: SizedBox(
          height: 110,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 拖拽提示条
                Center(
                  child: Container(
                    width: 24,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: GameBoyPalette.screenMid,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
                // 音标
                if (word.usPron.isNotEmpty || word.ukPron.isNotEmpty) ...[
                  Text(
                    '🔊 ${word.usPron}  ${word.ukPron}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: GameBoyPalette.screenLight),
                  ),
                  const SizedBox(height: 4),
                ],
                // 释义（优先结构化释义）
                if (meaningText.isNotEmpty) ...[
                  Text(
                    meaningText.length > 80 ? '${meaningText.substring(0, 80)}...' : meaningText,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: GameBoyPalette.screenLight),
                  ),
                  const SizedBox(height: 4),
                ],
                // 例句（结构化）
                ..._buildExampleSection(word),
                // 词根（结构化）
                ..._buildWordRootSection(word),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 例句结构化显示
  List<Widget> _buildExampleSection(Word word) {
    if (word.example.isEmpty) return const [];
    final sentences = ExampleParser.parse(word.example);
    if (sentences.isEmpty) return const [];
    return [
      const Text(
        '📖 例句:',
        style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: GameBoyPalette.screenMid),
      ),
      ...sentences.map((s) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                s.en,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: GameBoyPalette.screenLight),
              ),
            ),
            if (s.audioUrl != null && s.audioUrl!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.volume_up_outlined, color: GameBoyPalette.screenMid, size: 14),
                onPressed: () => context.read<AudioPlaybackState>().playSentence(s.audioUrl!),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minHeight: 20, minWidth: 20),
              ),
          ],
        ),
      )),
      const SizedBox(height: 4),
    ];
  }

  /// 词根结构化显示
  List<Widget> _buildWordRootSection(Word word) {
    if (word.wordRoot.isEmpty) return const [];
    return [
      WordRootTab(wordRootJson: word.wordRoot),
    ];
  }

  /// 按钮区域
  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // D-pad（装饰用）
          _buildDpad(),
          // A / B 键
          Row(
            children: [
              // B 键（返回）
              GestureDetector(
                onTap: () => NavUtils.safePop(context),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: GameBoyPalette.buttonRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: GameBoyPalette.shadowBlack.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'B',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: GameBoyPalette.textWhite,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // A 键（确认/开始）
              GestureDetector(
                onTap: () {
                  if (!_started) {
                    _startGame();
                  } else if (_showResult) {
                    _nextWord();
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: GameBoyPalette.buttonPurple,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: GameBoyPalette.shadowBlack.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'A',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: GameBoyPalette.textWhite,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// D-pad 方向键（功能：上=上一个，下=下一个，左=详情，右=发音）
  Widget _buildDpad() {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 上 - 上一个单词
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: _started ? _previousWord : null,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _started ? GameBoyPalette.dpadGray : GameBoyPalette.dpadGray,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                child: Icon(Icons.keyboard_arrow_up, color: GameBoyPalette.screenDark, size: 20),
              ),
            ),
          ),
          // 下 - 下一个单词
          Positioned(
            bottom: 0,
            child: GestureDetector(
              onTap: _started ? _nextWordManual : null,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _started ? GameBoyPalette.dpadGray : GameBoyPalette.dpadGray,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                ),
                child: Icon(Icons.keyboard_arrow_down, color: GameBoyPalette.screenDark, size: 20),
              ),
            ),
          ),
          // 左 - 显示/隐藏详情
          Positioned(
            left: 0,
            child: GestureDetector(
              onTap: _started ? () => setState(() => _showWordDetails = !_showWordDetails) : null,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _started ? GameBoyPalette.dpadGray : GameBoyPalette.dpadGray,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                ),
                child: Icon(Icons.info_outline, color: GameBoyPalette.screenDark, size: 16),
              ),
            ),
          ),
          // 右 - 发音
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap: _started ? _playPronunciation : null,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _started ? GameBoyPalette.dpadGray : GameBoyPalette.dpadGray,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                ),
                child: Icon(Icons.volume_up, color: GameBoyPalette.screenDark, size: 16),
              ),
            ),
          ),
          // 中心圆
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: GameBoyPalette.dpadGray, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  /// 扬声器格栅
  Widget _buildSpeakerGrill() {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          children: List.generate(
            4,
            (i) => Container(
              width: 40,
              height: 3,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(color: GameBoyPalette.bodyDark, borderRadius: BorderRadius.circular(1)),
            ),
          ),
        ),
      ),
    );
  }
}

/// AnimatedBuilder 的简化版
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({super.key, required super.listenable, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }

  // ignore: annotate_overrides
  Animation get animation => listenable as Animation;
}
