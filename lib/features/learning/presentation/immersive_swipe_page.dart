// 由 Claude 团队生成 | Monster Word App

// 移植自 lib/pages/immersive_swipe_page.dart
// 沉浸刷词：全屏单词卡片，上滑=认识，下滑=不认识，纯记忆测试
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';

import 'package:word_app/core/router/nav_utils.dart';
import 'package:word_app/core/router/route_names.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart' show FsrsRating;
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/features/learning/application/learning_reward_service.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/widgets/confetti.dart';
import 'package:word_app/widgets/session_exit_guard.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';

class ImmersiveSwipePage extends StatefulWidget {
  const ImmersiveSwipePage({super.key});
  static const routeName = '/immersive_swipe';

  @override
  State<ImmersiveSwipePage> createState() => _ImmersiveSwipePageState();
}

class _ImmersiveSwipePageState extends State<ImmersiveSwipePage> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  int _knownCount = 0;
  int _unknownCount = 0;
  bool _isDragging = false;
  double _dragOffset = 0;
  DateTime? _sessionStart;
  late ConfettiController _confettiController;
  bool _celebrated = false;
  bool _emptyAtEntry = false;
  int? _grantedCoins;

  /// 会话结算发币（每会话一次）；失败静默不打断完成页。
  Future<void> _settleRewards(BuildContext context, LearningSessionState state, int total) async {
    try {
      // 队列未重载再次进入（如皮肤页「立即体验」）会重挂载本页；
      // 会话级标记保证只在真正的新会话结算一次
      if (state.sessionRewardSettled) return;
      state.markSessionRewardSettled();
      final store = context.read<ScareCoinStore>();
      final service = LearningRewardService(store);
      final result = await service.settleSession(wordsLearned: total, dailyGoalAchieved: state.dailyGoalAchieved);
      if (!mounted || result.totalGranted <= 0) return;
      setState(() => _grantedCoins = result.totalGranted);
    } catch (_) {
      // 奖励结算失败不打断完成页
    }
  }

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    _confettiController = ConfettiController();
    _slideController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _fadeController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);
    // 入口即空队列（如皮肤页「立即体验」且无进行中会话）：
    // 展示引导空页而非「刷词完成」，避免 0 词完成页误导
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sessionState = context.read<LearningSessionState>();
      if (sessionState.queue.isEmpty && mounted) {
        setState(() => _emptyAtEntry = true);
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset += details.delta.dy;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final state = context.read<LearningSessionState>();
    final threshold = 100.0;

    if (_dragOffset < -threshold) {
      // 上滑 = 认识（触感反馈：体验审计 P1）
      unawaited(HapticFeedback.mediumImpact());
      _slideOut(const Offset(0, -2), () {
        setState(() {
          _knownCount++;
          _dragOffset = 0;
          _isDragging = false;
        });
        state.rate(FsrsRating.good);
      });
    } else if (_dragOffset > threshold) {
      // 下滑 = 不认识
      unawaited(HapticFeedback.lightImpact());
      _slideOut(const Offset(0, 2), () {
        setState(() {
          _unknownCount++;
          _dragOffset = 0;
          _isDragging = false;
        });
        state.rate(FsrsRating.again);
      });
    } else {
      // 回弹
      setState(() {
        _dragOffset = 0;
        _isDragging = false;
      });
    }
  }

  void _slideOut(Offset endOffset, VoidCallback onComplete) {
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: endOffset,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeIn));

    _slideController.forward(from: 0).then((_) {
      _fadeController.forward(from: 0).then((_) {
        onComplete();
        _fadeController.reverse();
      });
    });
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

  /// 入口空队列引导页：没有可刷的词时给明确指引，而非误导性的「刷词完成」
  Widget _buildEmptyEntry(BuildContext context, SkinSystem skin) {
    final colors = skin.colors;
    return Scaffold(
      backgroundColor: colors.pageBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.style_outlined, size: 72, color: colors.accent),
                const SizedBox(height: 20),
                Text(
                  '还没有可刷的单词',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.text1),
                ),
                const SizedBox(height: 8),
                Text(
                  '先去选择一本词书，再来体验沉浸刷词吧',
                  style: TextStyle(fontSize: 15, color: colors.text2),
                  textAlign: TextAlign.center,
                ),
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
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.libSelect);
                    },
                    child: const Text('去选词书', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('返回')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 完成页：对齐 Learn 页规格（庆祝动画 + 目标达成横幅 + 统计卡 + 主操作按钮）
  Widget _buildCompletion(BuildContext context, SkinSystem skin, LearningSessionState state) {
    final total = _knownCount + _unknownCount;
    final duration = _sessionStart == null ? null : DateTime.now().difference(_sessionStart!).inSeconds;
    if (!_celebrated) {
      _celebrated = true;
      unawaited(HapticFeedback.mediumImpact());
      WidgetsBinding.instance.addPostFrameCallback((_) => _confettiController.play());
      _settleRewards(context, state, total);
    }

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: ConfettiOverlay(
        controller: _confettiController,
        particleCount: 40,
        direction: ConfettiDirection.down,
        duration: const Duration(seconds: 3),
        colors: const [Color(0xFF006241), Color(0xFF00754A), Color(0xFFcba258), Color(0xFFFFD93D), Color(0xFF6BCB77)],
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.celebration, size: 80, color: skin.colors.accent),
                const SizedBox(height: 24),
                Text(
                  '🎉 刷词完成！',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: skin.colors.text1),
                ),
                const SizedBox(height: 12),
                // 今日目标达成庆祝横幅
                if (state.dailyGoalAchieved) ...[_buildGoalAchievedBanner(skin, state), const SizedBox(height: 12)],
                // 尖叫币奖励横幅（本次会话结算所得）
                if (_grantedCoins != null && _grantedCoins! > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: skin.colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: skin.colors.accent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('👹', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          '尖叫币 +$_grantedCoins',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: skin.colors.accent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  '本次共刷过 $total 个单词',
                  style: TextStyle(fontSize: 16, color: skin.colors.text2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: skin.colors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: skin.colors.divider),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ImmersiveStatItem(
                        label: '答对率',
                        value: total == 0 ? '--' : '${((_knownCount / total) * 100).round()}%',
                        colors: skin.colors,
                      ),
                      _ImmersiveStatItem(
                        label: '用时',
                        value: duration == null ? '--' : _formatDuration(duration),
                        colors: skin.colors,
                      ),
                      _ImmersiveStatItem(label: '不认识', value: '$_unknownCount', colors: skin.colors),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: skin.colors.accent,
                      foregroundColor: skin.colors.onGlassAccent,
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
      ),
    );
  }

  /// 今日目标达成横幅（🏅 已学 X / 目标 Y）
  Widget _buildGoalAchievedBanner(SkinSystem skin, LearningSessionState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: skin.colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: skin.colors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏅', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '今日目标达成！已学 ${state.todayLearned} / 目标 ${state.dailyGoal}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: skin.colors.accent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final state = context.watch<LearningSessionState>();
    final word = state.currentWord;

    if (word == null) {
      // 入口即空队列：引导先去选词书，而非展示 0 词完成页
      if (_emptyAtEntry) {
        return _buildEmptyEntry(context, skin);
      }
      return _buildCompletion(context, skin, state);
    }

    return SessionExitGuard(
      subject: '沉浸刷词',
      shouldIntercept: () => state.hasProgress,
      child: Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: SafeArea(
          child: Column(
            children: [
              // 顶部栏
              _buildTopBar(skin, state),
              // 卡片区
              Expanded(
                child: GestureDetector(
                  onVerticalDragUpdate: _onVerticalDragUpdate,
                  onVerticalDragEnd: _onVerticalDragEnd,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Transform.translate(
                        offset: Offset(0, _isDragging ? _dragOffset * 0.5 : 0),
                        child: _buildCard(word, skin, resp),
                      ),
                    ),
                  ),
                ),
              ),
              // 底部提示
              _buildBottomHint(skin),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(SkinSystem skin, LearningSessionState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, color: skin.colors.text1, size: 24),
            onPressed: () => NavUtils.safePop(context),
          ),
          const Spacer(),
          // 统计
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: skin.colors.cardBgAlt, borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, color: skin.colors.success, size: 16),
                const SizedBox(width: 4),
                Text('$_knownCount', style: MistralTypography.captionBold.copyWith(color: skin.colors.success)),
                const SizedBox(width: 12),
                Icon(Icons.close, color: skin.colors.danger, size: 16),
                const SizedBox(width: 4),
                Text('$_unknownCount', style: MistralTypography.captionBold.copyWith(color: skin.colors.danger)),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // 占位平衡
        ],
      ),
    );
  }

  Widget _buildCard(dynamic word, SkinSystem skin, AppResponsive resp) {
    // 拖拽时的颜色指示
    Color borderColor = skin.colors.divider;
    if (_isDragging) {
      if (_dragOffset < -50) {
        borderColor = skin.colors.success.withValues(alpha: 0.6);
      } else if (_dragOffset > 50) {
        borderColor = skin.colors.danger.withValues(alpha: 0.6);
      }
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: resp.pageMargin, vertical: 16),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [BoxShadow(color: MistralColors.black15, blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 单词
              Text(
                word.word,
                style: TextStyle(fontSize: resp.heroFontSize, fontWeight: FontWeight.w700, color: skin.colors.text1),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // 音标
              if (word.usPron.isNotEmpty)
                Text('/${word.usPron}/', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
              const SizedBox(height: 24),
              // 释义（始终显示，不再需要点击揭示 — 避免破坏"认识/不认识"体验）
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: skin.colors.cardBgAlt, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  word.hasStructuredDefinitions ? word.formattedDefinitions : word.cleanInterpret,
                  style: MistralTypography.body.copyWith(color: skin.colors.text1, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomHint(SkinSystem skin) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_upward, color: skin.colors.success.withValues(alpha: 0.6), size: 18),
          const SizedBox(width: 4),
          Text('认识', style: MistralTypography.caption.copyWith(color: skin.colors.text3)),
          const SizedBox(width: 24),
          Icon(Icons.arrow_downward, color: skin.colors.danger.withValues(alpha: 0.6), size: 18),
          const SizedBox(width: 4),
          Text('不认识', style: MistralTypography.caption.copyWith(color: skin.colors.text3)),
        ],
      ),
    );
  }
}

/// 沉浸刷词完成页统计项（对齐 Learn 页规格）
class _ImmersiveStatItem extends StatelessWidget {
  final String label;
  final String value;
  final dynamic colors;

  const _ImmersiveStatItem({required this.label, required this.value, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors.accent),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: colors.text3)),
      ],
    );
  }
}
