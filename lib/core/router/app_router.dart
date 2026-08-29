// AppRouter — 路由协调器（从 main.dart 抽取）

import 'package:flutter/material.dart';

import 'package:word_app/widgets/transition_widgets.dart';
import 'package:word_app/core/router/account_routes.dart';
import 'package:word_app/core/router/content_routes.dart';
import 'package:word_app/core/router/learning_routes.dart';
import 'package:word_app/core/router/route_error_page.dart';
import 'package:word_app/core/router/route_names.dart';

export 'package:word_app/core/router/route_names.dart';

/// 应用路由协调器。
///
/// 路由名称、功能域页面映射、错误页和转场策略分别拆分。该类只按固定顺序委托给
/// 功能域路由，并保留未知路由和转场的既有行为。
abstract final class AppRouter {
  /// 根据路由设置生成页面。
  static Widget? buildPage(RouteSettings settings) {
    final name = settings.name;
    final args = settings.arguments;
    return LearningRoutes.build(name, args) ??
        ContentRoutes.build(name, args) ??
        AccountRoutes.build(name, args) ??
        RouteErrorPage(routeName: name ?? 'unknown', message: '页面不存在');
  }

  /// 根据路由名称选择转场动画。
  static Route<dynamic> buildPageRoute(String? name, Widget page) {
    switch (name) {
      // 上滑进入：设置/个人中心/仪表盘/外观。
      case RouteNames.settings:
      case RouteNames.mySpace:
      case RouteNames.dashboard:
      case RouteNames.appearance:
      case RouteNames.moreSettings:
      case RouteNames.wordMachine:
      case RouteNames.themeSelect:
      case RouteNames.designLanguage:
      case RouteNames.userInfoManage:
      case RouteNames.help:
      case RouteNames.netDiagnosis:
      case RouteNames.checkInHistory:
        return SlideUpRoute(page: page) as Route<dynamic>;

      // 渐变进入：学习会话/复习会话。
      case RouteNames.learnSession:
      case RouteNames.reviewSession:
      case RouteNames.learn:
      case RouteNames.review:
        return FadeRoute(page: page) as Route<dynamic>;

      // 缩放进入：搜索/弹窗类。
      case RouteNames.search:
        return ScaleRoute(page: page) as Route<dynamic>;

      // 默认水平滑动（标准 Android 转场）。
      default:
        return MaterialPageRoute(builder: (_) => page);
    }
  }
}
