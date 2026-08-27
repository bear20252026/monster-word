import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/router/app_router.dart';
import 'package:word_app/pages/review_page.dart';

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
  });
}
