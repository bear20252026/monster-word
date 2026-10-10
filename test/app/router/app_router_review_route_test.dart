import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/app/router/app_router.dart';
import 'package:word_app/app/router/route_error_page.dart';
import 'package:word_app/features/learning/presentation/review_page.dart';
import 'package:word_app/widgets/transition_widgets.dart';

void main() {
  group('AppRouter review routes', () {
    test('正式复习路由解析为唯一的正式复习页面', () {
      final page = AppRouter.buildPage(const RouteSettings(name: RouteNames.review));

      expect(page, isA<ReviewPage>());
    });

    test('历史复习深链重定向至正式复习页面', () {
      final page = AppRouter.buildPage(const RouteSettings(name: '/review_session'));

      expect(page, isA<ReviewPage>());
    });

    test('功能域路由保留缺失必需参数时的友好错误页', () {
      final page = AppRouter.buildPage(const RouteSettings(name: RouteNames.listeningPlayer));

      expect(page, isA<RouteErrorPage>());
    });

    test('历史复习深链仍使用正式复习的渐变转场', () {
      final route = AppRouter.buildPageRoute(const RouteSettings(name: RouteNames.reviewSession), const ReviewPage());

      expect(route, isA<FadeRoute>());
    });

    test('MW-26 REG-ROUTE-001：生产路由保留 RouteSettings 的 name 与 arguments', () {
      final settings = RouteSettings(name: RouteNames.wordDetail, arguments: 'probe-word');
      final page = AppRouter.buildPage(settings)!;
      final route = AppRouter.buildPageRoute(settings, page);

      expect(route.settings.name, RouteNames.wordDetail);
      expect(route.settings.arguments, 'probe-word');
    });

    test('MW-26 REG-ROUTE-002：默认分支（MaterialPageRoute）同样透传 settings', () {
      final settings = RouteSettings(name: RouteNames.wordDetail, arguments: 42);
      final page = AppRouter.buildPage(settings)!;
      final route = AppRouter.buildPageRoute(settings, page);

      expect(route, isA<MaterialPageRoute<dynamic>>());
      expect(route.settings.name, RouteNames.wordDetail);
      expect(route.settings.arguments, 42);
    });
  });
}
