// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 转场动画控件
// 文件：SplashTransition, MySpaceTransition, UserInfoManageReturnFadeTransition

import 'package:word_app/tokens/motion_tokens.dart';
import 'package:flutter/material.dart';

import 'package:word_app/widgets/animations.dart';

/// 页面转场路由
/// 通用的页面转场效果
class SlideUpRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  SlideUpRoute({required this.page, this.duration = MotionDurations.slow})
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

/// 渐隐转场路由
class FadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  FadeRoute({required this.page, this.duration = MotionDurations.slow})
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

  ScaleRoute({required this.page, this.duration = MotionDurations.slow})
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
