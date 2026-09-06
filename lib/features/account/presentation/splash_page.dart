// 由 Claude 团队生成 | Monster Word App

// 启动页：品牌开场动画「记忆生长」→ 检查登录状态 → 跳转首页或登录页。
// 动画分镜见 lib/widgets/brand_intro.dart；全程点按可跳过（最短展示 800ms
// 的会话安全下限保留，避免会话未恢复时误判登录态）。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/brand_intro.dart';
import 'package:word_app/features/account/presentation/app_session_state.dart';
import 'package:word_app/features/account/presentation/login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  static const routeName = '/splash';

  @override
  State<SplashPage> createState() => _SplashPageState();
}

enum _SplashPhase { playing, routing, guide, completed }

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _showGuide = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  _SplashPhase _phase = _SplashPhase.playing;
  DateTime _createdAt = DateTime.now();

  /// 会话恢复与最短展示准备（由 _prepareSession 完成），与动画时间线并行等待。
  Future<void>? _sessionReady;
  Timer? _minShowTimer;

  // 引导页图片
  final List<String> _introAssets = [
    'assets/images/intro_0.png',
    'assets/images/intro_1.png',
    'assets/images/intro_2.png',
  ];

  @override
  void initState() {
    super.initState();
    // 「记忆生长」开场：2.8s 完整时间线；无障碍关闭动画时压缩到 300ms。
    // 路由由 AnimationStatus.completed 单一驱动，不再另设独立导航 Timer，
    // 消除动画时长与路由等待的双时间线竞态。
    final reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    _animController = AnimationController(
      vsync: this,
      duration: reduceMotion ? MotionDurations.splashQuick : MotionDurations.splash,
    );
    _animController.addStatusListener(_onAnimStatus);
    _createdAt = DateTime.now();
    _animController.forward();
    _prepareSession();
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _finishSplash();
  }

  /// 会话恢复与最短展示准备：不负责路由（路由统一在 _finishSplash）。
  void _prepareSession() {
    final minShow = Completer<void>();
    // 保留最短 800ms 展示：保证会话恢复完成、避免误判登录态（体验审计 C1）。
    // 用可取消 Timer 替代 Future.delayed，dispose 时取消，避免测试/快速退出挂起 Timer。
    final elapsed = DateTime.now().difference(_createdAt);
    final rest = const Duration(milliseconds: 800) - elapsed;
    if (rest <= Duration.zero) {
      minShow.complete();
    } else {
      _minShowTimer = Timer(rest, () => minShow.complete());
    }
    _sessionReady = minShow.future;
  }

  /// 点按跳过：把动画快进到收尾，由状态监听器触发 _finishSplash，无重复导航。
  void _skipIntro() {
    if (_phase != _SplashPhase.playing || _showGuide) return;
    _animController.animateTo(1.0, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  }

  /// 唯一导航入口：幂等，等待最短展示 + 会话恢复后按登录态路由。
  Future<void> _finishSplash() async {
    if (_phase == _SplashPhase.routing || _phase == _SplashPhase.guide || _phase == _SplashPhase.completed) {
      return;
    }
    _phase = _SplashPhase.routing;
    try {
      await _sessionReady;
      if (!mounted) return;
    } catch (_) {
      // 会话准备异常不阻塞路由，走下方 fail-safe。
    }

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
          _phase = _SplashPhase.guide;
          setState(() => _showGuide = true);
        } else {
          _phase = _SplashPhase.completed;
          _goToMain();
        }
      } else {
        _phase = _SplashPhase.completed;
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
    _minShowTimer?.cancel();
    _animController.removeStatusListener(_onAnimStatus);
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
                              foregroundColor: AppColors.white100,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(context.design.radius.pill),
                              ),
                            ),
                            child: const Text('开始使用'),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              _pageController.nextPage(duration: MotionDurations.slow, curve: Curves.easeOutCubic);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: skin.colors.accent,
                              foregroundColor: AppColors.white100,
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
