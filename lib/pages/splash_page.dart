// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 SplashActivity
// 启动页：品牌动画 → 检查登录状态 → 跳转首页或登录页
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../widgets/animations.dart';
import '../tokens/design_tokens.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  static const routeName = '/splash';

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _showGuide = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 引导页图片（对应原版 introImages）
  final List<String> _introAssets = [
    'assets/images/intro_0.png',
    'assets/images/intro_1.png',
    'assets/images/intro_2.png',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.6)),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: standardCurve),
    );
    _animController.forward();
    _checkLoginAndNavigate();
  }

  Future<void> _checkLoginAndNavigate() async {
    // 等待动画播放 + 模拟网络检查
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final state = context.read<LearningState>();
    final isLoggedIn = state.isLoggedIn;

    if (isLoggedIn) {
      // 已登录 → 检查是否首次启动（显示引导页）
      final hasShownGuide = state.hasShownInitGuide;
      if (!hasShownGuide) {
        setState(() => _showGuide = true);
        await state.setHasShownInitGuide(true);
      } else {
        _goToMain();
      }
    } else {
      // 未登录 → 跳转登录页
      _goToLogin();
    }
  }

  void _goToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(LoginPage.routeName);
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    if (_showGuide) {
      return _buildGuideView(skin);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // "不" — 橙色描边圆圈
                SizedBox(
                  width: 56,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF6800),
                        width: 2.5,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        '不',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF6800),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // "背" — 橙色实心圆
                SizedBox(
                  width: 56,
                  height: 56,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF6800),
                    ),
                    child: const Center(
                      child: Text(
                        '背',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // "单" "词" — 黑色竖排
                const Text(
                  '单',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F1F1F),
                    height: 1.2,
                  ),
                ),
                const Text(
                  '词',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F1F1F),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 引导页（对应原版 ViewPager + introImages）
  Widget _buildGuideView(SkinSystem skin) {
    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _introAssets.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: MistralColors.cream,
                            ),
                            child: Center(
                              child: Icon(
                                _getGuideIcon(index),
                                size: 120,
                                color: MistralColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _getGuideTitle(index),
                          style: MistralTypography.heading4.copyWith(
                            color: skin.colors.text1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getGuideDesc(index),
                          textAlign: TextAlign.center,
                          style: MistralTypography.body.copyWith(
                            color: skin.colors.text3,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // 圆点指示器 + 开始按钮
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_introAssets.length, (i) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _currentPage
                              ? MistralColors.primary
                              : MistralColors.hairline,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  if (_currentPage == _introAssets.length - 1)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _goToMain,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MistralColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        child: const Text('开始使用'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getGuideIcon(int index) {
    switch (index) {
      case 0: return Icons.school;
      case 1: return Icons.psychology;
      case 2: return Icons.trending_up;
      default: return Icons.menu_book;
    }
  }

  String _getGuideTitle(int index) {
    switch (index) {
      case 0: return '科学记忆';
      case 1: return '沉浸学习';
      case 2: return '持续进步';
      default: return '';
    }
  }

  String _getGuideDesc(int index) {
    switch (index) {
      case 0: return '基于艾宾浩斯遗忘曲线，智能安排复习时间';
      case 1: return '真实语境例句，让单词记忆更深刻';
      case 2: return '每日打卡，见证词汇量飞速增长';
      default: return '';
    }
  }
}
