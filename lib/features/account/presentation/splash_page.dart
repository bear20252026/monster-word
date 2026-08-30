// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 SplashActivity
// 启动页：品牌动画 → 检查登录状态 → 跳转首页或登录页
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/animations.dart';
import 'package:word_app/widgets/liquid_logo.dart';
import 'package:word_app/widgets/path_marquee.dart';
import 'package:word_app/widgets/meteors.dart';
import 'package:word_app/features/account/presentation/app_session_state.dart';
import 'package:word_app/features/account/presentation/login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  static const routeName = '/splash';

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _showGuide = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // A-2: 持有导航 Timer 以便在 dispose 时取消，避免测试/快速退出时留下 pending Timer。
  Timer? _navTimer;

  // 引导页图片（对应原版 introImages）
  final List<String> _introAssets = [
    'assets/images/intro_0.png',
    'assets/images/intro_1.png',
    'assets/images/intro_2.png',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.6)));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: standardCurve));
    _animController.forward();
    _checkLoginAndNavigate();
  }

  Future<void> _checkLoginAndNavigate() async {
    // 等待动画播放 + 模拟网络检查。Timer 持有引用，dispose 时取消，避免 pending Timer。
    _navTimer?.cancel();
    _navTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _proceedToRoute();
    });
  }

  Future<void> _proceedToRoute() async {
    final session = context.read<AppSessionState>();
    final isLoggedIn = session.isLoggedIn;

    if (isLoggedIn) {
      // 已登录 → 检查是否首次启动（显示引导页）
      final hasShownGuide = session.hasShownInitGuide;
      if (!hasShownGuide) {
        await session.setHasShownInitGuide(true);
        if (!mounted) return;
        setState(() => _showGuide = true);
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
    _navTimer?.cancel();
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
      backgroundColor: skin.colors.pageBg,
      body: Stack(
        children: [
          // 流星雨背景（仅在深色主题时显示）
          if (skin.colors.pageBg.computeLuminance() < 0.3)
            const Positioned.fill(
              child: MeteorShower(
                count: 15,
                enableStars: true,
                colors: [Color(0xFF006241), Color(0xFF00754A), Color(0xFFcba258), Color(0xFF4D96FF)],
              ),
            ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 液态 Logo 动画
                    LiquidLogo(
                      size: 100,
                      colors: [
                        skin.colors.accent,
                        skin.colors.accent.withValues(alpha: 0.8),
                        const Color(0xFF1E3932),
                        const Color(0xFFcba258),
                      ],
                      child: ExcludeSemantics(
                        child: Text(
                          '怪',
                          style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // 品牌名
                    Text(
                      'Monster Word',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: skin.colors.text1,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('背单词 · 从未如此有趣', style: TextStyle(fontSize: 13, color: skin.colors.text3)),
                    SizedBox(height: 24),
                    // 波浪滚动文字装饰
                    PathMarquee(
                      text: 'Monster Word · 背单词 · 从未如此有趣 · ',
                      pathType: MarqueePathType.sine,
                      pathWidth: 280,
                      pathHeight: 30,
                      speed: 0.6,
                      loopDuration: const Duration(seconds: 5),
                      textStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: skin.colors.text3.withValues(alpha: 0.7),
                      ),
                      showPath: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: skin.colors.pageBg,
                            ),
                            child: Center(child: Icon(_getGuideIcon(index), size: 120, color: skin.colors.accent)),
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          _getGuideTitle(index),
                          style: MistralTypography.heading4.copyWith(color: skin.colors.text1),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _getGuideDesc(index),
                          textAlign: TextAlign.center,
                          style: MistralTypography.body.copyWith(color: skin.colors.text3),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // 圆点指示器 + 前进按钮（每页都有，桌面端无滑动手势也能走完引导）
            Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  // 跳过：右上角，非最后页显示
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_currentPage < _introAssets.length - 1)
                        TextButton(
                          onPressed: _goToMain,
                          child: Text('跳过', style: TextStyle(color: skin.colors.text3)),
                        ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_introAssets.length, (i) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _currentPage ? skin.colors.accent : skin.colors.divider,
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: _currentPage == _introAssets.length - 1
                        ? ElevatedButton(
                            onPressed: _goToMain,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: skin.colors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.pill)),
                            ),
                            child: const Text('开始使用'),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: skin.colors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.pill)),
                            ),
                            child: const Text('下一步'),
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
      case 0:
        return Icons.school;
      case 1:
        return Icons.psychology;
      case 2:
        return Icons.trending_up;
      default:
        return Icons.menu_book;
    }
  }

  String _getGuideTitle(int index) {
    switch (index) {
      case 0:
        return '科学记忆';
      case 1:
        return '沉浸学习';
      case 2:
        return '持续进步';
      default:
        return '';
    }
  }

  String _getGuideDesc(int index) {
    switch (index) {
      case 0:
        return '基于艾宾浩斯遗忘曲线，智能安排复习时间';
      case 1:
        return '真实语境例句，让单词记忆更深刻';
      case 2:
        return '每日打卡，见证词汇量飞速增长';
      default:
        return '';
    }
  }
}
