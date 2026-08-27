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

  group('每日新学词数设置边界', () {
    test('设置状态是每日新学词数的唯一页面读写入口', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final settingsPageSource = File('lib/pages/settings_page.dart').readAsStringSync();
      final legacySource = File('lib/state/learning_state.dart').readAsStringSync();

      expect(appSource, contains('sl<SettingsState>()..init()'));
      expect(settingsPageSource, contains('SettingsState'));
      expect(settingsPageSource, isNot(contains("import 'package:shared_preferences/shared_preferences.dart';")));
      expect(settingsPageSource, isNot(contains('_dailyNewWords')));
      expect(legacySource, isNot(contains('daily_new_words_v1')));
      expect(legacySource, isNot(contains('setDailyNewWords')));
    });
  });

  group('生词本数据边界', () {
    test('生词本页面通过读取器和展示状态访问独立数据源', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final pageSource = File('lib/pages/new_words_page.dart').readAsStringSync();
      final footMarkSource = File('lib/pages/foot_mark_page.dart').readAsStringSync();
      final dictionarySource = File('lib/pages/dictionary_page.dart').readAsStringSync();
      final legacySource = File('lib/state/learning_state.dart').readAsStringSync();

      expect(appSource, contains('Provider<NewWordsReader>.value'));
      expect(appSource, contains('sl<NewWordsState>()..initialize()'));
      expect(pageSource, contains('NewWordsReader'));
      expect(pageSource, contains('NewWordsState'));
      expect(pageSource, isNot(contains('LearningState')));
      expect(footMarkSource, contains('newWords.count'));
      expect(dictionarySource, contains('NewWordsState'));
      expect(dictionarySource, contains("source: 'dictionary'"));
      expect(legacySource, isNot(contains('getNewWords')));
      expect(legacySource, isNot(contains('newWordNum')));
    });
  });

  group('已掌握词表查询边界', () {
    test('已掌握词表页面通过读取器加载数据', () {
      final source = File('lib/pages/mastered_words_page.dart').readAsStringSync();

      final appSource = File('lib/app/app.dart').readAsStringSync();

      expect(source, contains('MasteredWordsReader'));
      expect(source, contains('loadWordsForContext'));
      expect(appSource, contains('Provider<MasteredWordsReader>.value'));

      expect(source, isNot(contains('LearningState')));
      expect(source, isNot(contains('service_locator.dart')));
    });
  });

  group('词书单词查询边界', () {
    test('词书单词页通过读取器加载数据', () {
      final source = File('lib/pages/book_words_page.dart').readAsStringSync();
      final appSource = File('lib/app/app.dart').readAsStringSync();

      expect(source, contains('BookWordsReader'));
      expect(source, contains('loadWordsForContext'));
      expect(appSource, contains('Provider<BookWordsReader>.value'));
      expect(source, isNot(contains('LearningState')));
    });
  });

  group('队列分类词表查询边界', () {
    test('队列分类词表页通过展示适配器加载数据', () {
      const pages = [
        'lib/pages/my_words_page.dart',
        'lib/pages/not_learned_words_page.dart',
        'lib/pages/reviewing_words_page.dart',
      ];
      final appSource = File('lib/app/app.dart').readAsStringSync();

      expect(appSource, contains('LearningQueueWordListsState'));
      for (final path in pages) {
        final source = File(path).readAsStringSync();
        expect(source, contains('LearningQueueWordListsState'), reason: '$path 应读取队列词表展示适配器');
        expect(source, isNot(contains('LearningState')), reason: '$path 不应直接读取遗留 LearningState');
      }
    });
  });

  group('学习集合展示状态边界', () {
    test('足迹页通过集合展示状态读取掌握数量', () {
      final source = File('lib/pages/foot_mark_page.dart').readAsStringSync();

      expect(source, contains('LearningCollectionsState'));
      expect(source, contains('collections.masteredCount'));
      expect(source, isNot(contains('count: state.masteredNum')));
    });

    test('我的内容页只读取收藏集合展示状态', () {
      final source = File('lib/pages/my_content_page.dart').readAsStringSync();

      expect(source, contains('LearningCollectionsState'));
      expect(source, isNot(contains('LearningState')));
    });
  });

  group('学习统计状态边界', () {
    test('首页与仪表盘只读取学习统计状态', () {
      const statisticsPages = ['lib/screens/home_screen.dart', 'lib/pages/dashboard_page.dart'];

      for (final path in statisticsPages) {
        final source = File(path).readAsStringSync();
        expect(source, contains('LearningStatisticsState'), reason: '$path 应读取 LearningStatisticsState');
        expect(source, isNot(contains('LearningState')), reason: '$path 不应直接读取遗留 LearningState');
      }
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
