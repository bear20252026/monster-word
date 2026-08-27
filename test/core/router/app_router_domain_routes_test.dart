import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/router/app_router.dart';
import 'package:word_app/core/router/route_error_page.dart';
import 'package:word_app/pages/learn_page.dart';
import 'package:word_app/pages/search_page.dart';
import 'package:word_app/pages/settings_page.dart';
import 'package:word_app/pages/review_page.dart';

void main() {
  group('AppRouter 功能域委托', () {
    test('学习、内容和账户路由保持原页面类型', () {
      expect(AppRouter.buildPage(const RouteSettings(name: RouteNames.learn)), isA<LearnPage>());
      expect(AppRouter.buildPage(const RouteSettings(name: RouteNames.search)), isA<SearchPage>());
      expect(AppRouter.buildPage(const RouteSettings(name: RouteNames.settings)), isA<SettingsPage>());
    });

    test('历史复习深链和未知路由保持各自的兼容结果', () {
      expect(AppRouter.buildPage(const RouteSettings(name: RouteNames.reviewSession)), isA<ReviewPage>());
      expect(AppRouter.buildPage(const RouteSettings(name: '/not-a-route')), isA<RouteErrorPage>());
    });
  });
}
