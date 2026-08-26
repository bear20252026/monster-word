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
      expect(appSource, isNot(contains('ErrorWidget.builder')));
    });

    test('启动器不依赖页面展示层', () {
      final bootstrapSource = File('lib/app/app_bootstrap.dart').readAsStringSync();

      expect(bootstrapSource, contains('Future<void> bootstrapApp() async'));
      expect(bootstrapSource, contains('ErrorWidget.builder'));
      expect(bootstrapSource, isNot(contains("import '../pages/")));
      expect(bootstrapSource, isNot(contains('MaterialApp')));
    });
  });

  group('学习会话状态边界', () {
    test('学习会话页面统一读取 LearnState', () {
      const sessionPages = [
        'lib/pages/learn_page.dart',
        'lib/screens/learn_session.dart',
        'lib/pages/word_machine_page.dart',
      ];

      for (final path in sessionPages) {
        final source = File(path).readAsStringSync();
        expect(source, contains('LearnState'), reason: '$path 应读取 LearnState');
        expect(source, isNot(contains('LearningState')), reason: '$path 不应直接读取遗留 LearningState');
      }
    });
  });
}
