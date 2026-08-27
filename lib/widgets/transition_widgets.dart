// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 转场动画控件：翻译自 widget/ 中的转场类
// 文件：SplashTransition, MySpaceTransition, UserInfoManageReturnFadeTransition

import 'package:flutter/material.dart';

import 'animations.dart';

/// 启动页转场动画（翻译自 SplashTransition.dart）
/// 向上滑动 + 渐隐
class SplashExitTransition extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double slideDistance;
  final VoidCallback? onComplete;

  const SplashExitTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 100),
    this.slideDistance = 130.0,
    this.onComplete,
  });

  @override
  State<SplashExitTransition> createState() => _SplashExitTransitionState();
}

class _SplashExitTransitionState extends State<SplashExitTransition> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _slideAnim = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(0, -widget.slideDistance),
    ).animate(CurvedAnimation(parent: _controller, curve: splashExitCurve));
    _fadeAnim = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: splashExitCurve));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void startExit() {
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(opacity: _fadeAnim, child: widget.child),
    );
  }
}

/// 页面转场路由（翻译自 SplashTransition / MySpaceTransition）
/// 通用的页面转场效果
class SlideUpRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  SlideUpRoute({required this.page, this.duration = const Duration(milliseconds: 300)})
    : super(
        transitionDuration: duration,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(CurveTween(curve: standardCurve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      );
}

/// 渐隐转场路由（翻译自 UserInfoManageReturnFadeTransition.dart）
class FadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  FadeRoute({required this.page, this.duration = const Duration(milliseconds: 300)})
    : super(
        transitionDuration: duration,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      );
}

/// 缩放转场路由
class ScaleRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  ScaleRoute({required this.page, this.duration = const Duration(milliseconds: 300)})
    : super(
        transitionDuration: duration,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween<double>(begin: 0.8, end: 1.0).chain(CurveTween(curve: standardCurve));
          final fadeTween = Tween<double>(begin: 0.0, end: 1.0);
          return ScaleTransition(
            scale: animation.drive(tween),
            child: FadeTransition(opacity: animation.drive(fadeTween), child: child),
          );
        },
      );
}

/// 转场工具类
class TransitionUtils {
  /// 推入渐隐页面
  static Future<T?> pushFade<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(context, FadeRoute(page: page));
  }

  /// 推入上滑页面
  static Future<T?> pushSlideUp<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(context, SlideUpRoute(page: page));
  }

  /// 推入缩放页面
  static Future<T?> pushScale<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(context, ScaleRoute(page: page));
  }
}
