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

  group('复习主入口边界', () {
    test('回顾弹窗将开始复习路由到正式到期词流程', () {
      final source = File('lib/widgets/review_dialog.dart').readAsStringSync();

      expect(source, contains("import '../pages/review_page.dart';"));
      expect(source, contains('nav.pushNamed(ReviewPage.routeName)'));
      expect(source, isNot(contains("nav.pushNamed('/review_session')")));
    });
  });

  group('复习队列读取边界', () {
    test('正式会话通过队列快照和读取器获取候选词', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final pageSource = File('lib/pages/review_page.dart').readAsStringSync();
      final sessionSource = File('lib/features/learning/presentation/review_session_state.dart').readAsStringSync();

      expect(appSource, contains('ReviewQueueState'));
      expect(appSource, contains('Provider<ReviewQueueReader>.value'));
      expect(pageSource, contains('ReviewQueueState'));
      expect(pageSource, contains('ReviewSessionState'));
      expect(pageSource, contains('initialize(reviewQueue.snapshot)'));
      expect(pageSource, isNot(contains('ReviewQueueReader')));
      expect(sessionSource, contains('ReviewQueueReader'));
      expect(sessionSource, contains('_queueReader.loadWords(snapshot)'));
      expect(sessionSource, isNot(contains('state.dueWords')));
      expect(sessionSource, isNot(contains('state.queue')));
      expect(sessionSource, isNot(contains('sl<WordRepository>()')));
    });
  });

  group('正式复习页面展示组件边界', () {
    test('路由协调层依赖聚合入口，主要视觉区域按职责拆分', () {
      final pageSource = File('lib/pages/review_page.dart').readAsStringSync();
      final widgetsSource = File('lib/features/learning/presentation/widgets/formal_review_widgets.dart')
          .readAsStringSync();
      final layoutSource = File('lib/features/learning/presentation/widgets/formal_review_session_layout.dart')
          .readAsStringSync();
      final headerSource = File('lib/features/learning/presentation/widgets/formal_review_header.dart')
          .readAsStringSync();
      final questionSource = File('lib/features/learning/presentation/widgets/formal_review_question.dart')
          .readAsStringSync();
      final choiceCardSource = File('lib/features/learning/presentation/widgets/formal_review_choice_card.dart')
          .readAsStringSync();
      final stateViewsSource = File('lib/features/learning/presentation/widgets/formal_review_state_views.dart')
          .readAsStringSync();

      expect(pageSource, contains('FormalReviewSessionLayout'));
      expect(pageSource, contains('FormalReviewLoadingView'));
      expect(pageSource, contains('FormalReviewLoadErrorView'));
      expect(pageSource, contains('FormalReviewCompleteView'));
      expect(pageSource, isNot(contains('class _FrostedChoiceCard')));
      expect(pageSource, isNot(contains('_buildChoiceArea')));
      expect(pageSource, isNot(contains('_buildWordArea')));
      expect(widgetsSource, contains("export 'formal_review_session_layout.dart';"));
      expect(widgetsSource, contains("export 'formal_review_header.dart';"));
      expect(widgetsSource, contains("export 'formal_review_question.dart';"));
      expect(widgetsSource, contains("export 'formal_review_choice_card.dart';"));
      expect(widgetsSource, contains("export 'formal_review_state_views.dart';"));
      expect(layoutSource, contains('class FormalReviewSessionLayout'));
      expect(layoutSource, contains('class FormalReviewWallpaper'));
      expect(headerSource, contains('class FormalReviewHeader'));
      expect(questionSource, contains('class FormalReviewWordPrompt'));
      expect(questionSource, contains('class FormalReviewChoiceGrid'));
      expect(questionSource, contains('class FormalReviewAnswerAction'));
      expect(choiceCardSource, contains('class FormalReviewChoiceCard'));
      expect(stateViewsSource, contains('class FormalReviewLoadingView'));
      expect(stateViewsSource, contains('class FormalReviewLoadErrorView'));
      expect(stateViewsSource, contains('class FormalReviewCompleteView'));
    });
  });

  group('正式复习加载与答题交互边界', () {
    test('页面映射会话快照和命令，展示组件不依赖会话状态实现', () {
      final pageSource = File('lib/pages/review_page.dart').readAsStringSync();
      final layoutSource = File('lib/features/learning/presentation/widgets/formal_review_session_layout.dart')
          .readAsStringSync();
      final headerSource = File('lib/features/learning/presentation/widgets/formal_review_header.dart')
          .readAsStringSync();
      final questionSource = File('lib/features/learning/presentation/widgets/formal_review_question.dart')
          .readAsStringSync();
      final sessionSource = File('lib/features/learning/presentation/review_session_state.dart').readAsStringSync();

      expect(pageSource, contains('session.isLoading'));
      expect(pageSource, contains('session.hasLoadError'));
      expect(pageSource, contains('FormalReviewLoadErrorView'));
      expect(pageSource, contains('selectedWrongChoice: session.selectedWrongChoice'));
      expect(pageSource, contains('onSelectChoice: session.selectChoice'));
      expect(pageSource, contains('onContinueWithGoodRating: session.continueWithGoodRating'));
      expect(pageSource, isNot(contains('_wrongChoiceIndex')));
      expect(pageSource, isNot(contains('Future.delayed')));
      expect(layoutSource, isNot(contains('ReviewSessionState')));
      expect(headerSource, isNot(contains('ReviewSessionState')));
      expect(questionSource, isNot(contains('ReviewSessionState')));
      expect(questionSource, contains('onSelectChoice(choice.word)'));
      expect(sessionSource, contains('ReviewSessionLoadPhase'));
      expect(sessionSource, contains('Timer'));
      expect(sessionSource, contains('String? get selectedWrongChoice'));
      expect(sessionSource, contains('selectChoice'));
      expect(sessionSource, contains('continueWithGoodRating'));
    });
  });

  group('正式复习撤销边界', () {
    test('不提供只回退计数而不回退题目的伪撤销操作', () {
      final pageSource = File('lib/pages/review_page.dart').readAsStringSync();
      final sessionSource = File('lib/features/learning/presentation/review_session_state.dart').readAsStringSync();

      expect(pageSource, isNot(contains('Icons.undo')));
      expect(pageSource, isNot(contains('_canUndo')));
      expect(pageSource, isNot(contains('_history')));
      expect(sessionSource, isNot(contains('undoProgress')));
    });
  });

  group('正式复习词条操作边界', () {
    test('主复习页通过协调状态读取并持久化收藏和手动掌握标记', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final pageSource = File('lib/pages/review_page.dart').readAsStringSync();
      final actionsSource = File('lib/features/learning/presentation/review_word_actions_state.dart')
          .readAsStringSync();

      expect(appSource, contains('ReviewWordActionsState'));
      expect(pageSource, contains('ReviewWordActionsState'));
      expect(pageSource, contains('wordActions.isFavorite'));
      expect(pageSource, contains('toggleFavorite(current.word)'));
      expect(pageSource, contains('markManuallyMastered(currentWord.word)'));
      expect(pageSource, isNot(contains('_isFavorited')));
      expect(pageSource, isNot(contains('TODO: persist favorite')));
      expect(actionsSource, contains('FavRepository'));
      expect(actionsSource, contains('MasteredRepository'));
    });
  });

  group('正式复习会话状态边界', () {
    test('主复习页通过会话展示状态管理本地题目与进度', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final pageSource = File('lib/pages/review_page.dart').readAsStringSync();

      expect(appSource, contains('ChangeNotifierProxyProvider<ReviewRatingWriter, ReviewSessionState>'));
      expect(pageSource, contains('ReviewSessionState'));
      expect(pageSource, contains('context.watch<ReviewSessionState>()'));
      expect(pageSource, isNot(contains('SuperMemoryEngine')));
      expect(pageSource, isNot(contains('ChoiceGenerator')));
      expect(pageSource, isNot(contains('ReviewQueueReader')));
    });
  });

  group('复习评分写入边界', () {
    test('正式会话通过评分写入端口提交 FSRS 评分', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final pageSource = File('lib/pages/review_page.dart').readAsStringSync();
      final sessionSource = File('lib/features/learning/presentation/review_session_state.dart').readAsStringSync();

      expect(appSource, contains('ProxyProvider<LearningState, ReviewRatingWriter>'));
      expect(appSource, contains('ReviewRatingWriter(writeRating: legacy.rateReviewWord)'));
      expect(pageSource, contains('onSelectChoice: session.selectChoice'));
      expect(pageSource, contains('onContinueWithGoodRating: session.continueWithGoodRating'));
      expect(pageSource, isNot(contains('ReviewRatingWriter')));
      expect(sessionSource, contains('ReviewRatingWriter'));
      expect(sessionSource, contains('final reviewedWord = currentWord'));
      expect(sessionSource, contains('_ratingWriter.rate(word: reviewedWord.word, rating: fsrsRating)'));
      expect(pageSource, isNot(contains('LearningState')));
    });
  });

  group('复习候选规则边界', () {
    test('正式会话复用共享候选生成规则', () {
      final pageSource = File('lib/pages/review_page.dart').readAsStringSync();
      final sessionSource = File('lib/features/learning/presentation/review_session_state.dart').readAsStringSync();

      expect(sessionSource, contains('ChoiceGenerator'));
      expect(sessionSource, contains('ChoiceCandidate'));
      expect(pageSource, isNot(contains('ChoiceGenerator')));
      expect(sessionSource, isNot(contains('dart:convert')));
      expect(sessionSource, isNot(contains('_extractCn')));
      expect(sessionSource, isNot(contains("'非标准用法'")));
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
