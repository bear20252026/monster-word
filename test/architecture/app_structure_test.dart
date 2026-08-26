import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('应用装配结构', () {
    test('main 仅承担进程启动职责', () {
      final mainSource = File('lib/main.dart').readAsStringSync();

      expect(mainSource, contains("import 'app/app.dart';"));
      expect(mainSource, contains("import 'app/app_bootstrap.dart';"));
      expect(mainSource, contains('await bootstrapApp();'));
      expect(mainSource, contains('runApp(const WordApp());'));
      expect(mainSource, isNot(contains('class _WordAppState')));
      expect(mainSource, isNot(contains('class _FriendlyErrorPage')));
      expect(mainSource, isNot(contains("import 'pages/")));
    });

    test('根组件通过统一路由装配页面', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();

      expect(appSource, contains("import '../core/router/app_router.dart';"));
      expect(appSource, contains('AppRouter.buildPage(settings)'));
      expect(appSource, contains('AppRouter.buildPageRoute(settings.name, page)'));
    });

    test('启动器不依赖页面展示层', () {
      final bootstrapSource = File('lib/app/app_bootstrap.dart').readAsStringSync();

      expect(bootstrapSource, contains('Future<void> bootstrapApp() async'));
      expect(bootstrapSource, isNot(contains("import '../pages/")));
      expect(bootstrapSource, isNot(contains('MaterialApp')));
    });
  });
}
