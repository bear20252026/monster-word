// 由 Claude 团队生成 | Monster Word App

// 移植自 lib/pages/immersive_swipe_page.dart
// 沉浸刷词：全屏单词卡片，上滑=认识，下滑=不认识，纯记忆测试
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/nav_utils.dart';
import '../../../core/engine/fsrs6_engine.dart' show FsrsRating;
import 'package:word_app/core/presentation/responsive.dart';
import '../../../widgets/session_exit_guard.dart';
import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';
import 'learning_session_state.dart';

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

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _fadeController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
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
      // 上滑 = 认识
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

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final state = context.watch<LearningSessionState>();
    final word = state.currentWord;

    if (word == null) {
      return Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: skin.colors.success),
              const SizedBox(height: 16),
              Text('刷词完成！', style: MistralTypography.heading4.copyWith(color: skin.colors.text1)),
              const SizedBox(height: 8),
              Text(
                '认识 $_knownCount · 不认识 $_unknownCount',
                style: MistralTypography.body.copyWith(color: skin.colors.text3),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => NavUtils.goHome(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: skin.colors.accent,
                  foregroundColor: AppColors.white100,
                ),
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      );
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
