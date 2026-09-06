// 由 Claude 团队生成 | Monster Word App

// 启动页：品牌开场动画「记忆生长」→ 检查登录状态 → 跳转首页或登录页。
// 动画分镜见 lib/widgets/brand_intro.dart；全程点按可跳过（最短展示 800ms
// 的会话安全下限保留，避免会话未恢复时误判登录态）。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/brand_intro.dart';
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
  bool _showGuide = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // A-2: 持有导航 Timer 以便在 dispose 时取消，避免测试/快速退出时留下 pending Timer。
  Timer? _navTimer;
  DateTime _createdAt = DateTime.now();
  bool _proceeding = false;

  // 引导页图片
  final List<String> _introAssets = [
    'assets/images/intro_0.png',
    'assets/images/intro_1.png',
    'assets/images/intro_2.png',
  ];

  @override
  void initState() {
    super.initState();
    // 「记忆生长」开场：2.8s 完整时间线；无障碍关闭动画时压缩到 300ms 快速淡入。
    final reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: reduceMotion ? 300 : 2800),
    );
    _createdAt = DateTime.now();
    _animController.forward();
    _checkLoginAndNavigate();
  }

  Future<void> _checkLoginAndNavigate() async {
    // 开场动画完整播完（2.8s）后导航；点按任意处可提前跳过（_skipIntro），
    // 但最短展示 800ms —— 会话恢复需要这一安全下限，避免误判登录态。
    _navTimer?.cancel();
    _navTimer = Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      _proceedToRoute();
    });
  }

  /// 点按跳过：动画快进到收尾，并越过剩余等待直接导航（不低于 800ms 安全下限）。
  void _skipIntro() {
    if (_proceeding || _showGuide) return;
    final elapsed = DateTime.now().difference(_createdAt);
    _animController.animateTo(1.0, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    final remaining = const Duration(milliseconds: 800) - elapsed;
    if (remaining <= Duration.zero) {
      _proceedToRoute();
    } else {
      _navTimer?.cancel();
      _navTimer = Timer(remaining, () {
        if (!mounted) return;
        _proceedToRoute();
      });
    }
  }

  Future<void> _proceedToRoute() async {
    if (_proceeding) return;
    _proceeding = true;
    // fail-safe：启动导航绝不允许卡在 Splash。任何异常都强制跳到
    // 登录页（未登录）或主页（已登录），让用户继续操作而非卡死。
    var isLoggedIn = false;
    var hasShownGuide = false;
    try {
      final session = context.read<AppSessionState>();
      isLoggedIn = session.isLoggedIn;
      hasShownGuide = session.hasShownInitGuide;
    } catch (e) {
      debugPrint('[Splash] 读取会话状态失败（fail-safe → 登录页）: $e');
      _goToLogin();
      return;
    }

    try {
      if (isLoggedIn) {
        if (!hasShownGuide) {
          await context.read<AppSessionState>().setHasShownInitGuide(true);
          if (!mounted) return;
          setState(() => _showGuide = true);
        } else {
          _goToMain();
        }
      } else {
        _goToLogin();
      }
    } catch (e) {
      debugPrint('[Splash] 启动导航失败（fail-safe → 登录页）: $e');
      if (mounted) _goToLogin();
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
      // 全屏点按 = 跳过开场
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skipIntro,
        child: Center(child: BrandIntro(animation: _animController)),
      ),
    );
  }

  /// 引导页
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
                        Text(_getGuideTitle(index), style: MwTypography.heading4.copyWith(color: skin.colors.text1)),
                        SizedBox(height: 8),
                        Text(
                          _getGuideDesc(index),
                          textAlign: TextAlign.center,
                          style: MwTypography.body.copyWith(color: skin.colors.text3),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(context.design.radius.pill),
                              ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(context.design.radius.pill),
                              ),
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
