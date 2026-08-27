import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('稳定启动与装配边界', () {
    test('启动器仅负责 bootstrap，根组件统一委托路由与学习功能域装配', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      final bootstrapSource = File('lib/app/app_bootstrap.dart').readAsStringSync();
      final appSource = File('lib/app/app.dart').readAsStringSync();

      expect(mainSource, contains('await bootstrapApp();'));
      expect(mainSource, contains('runApp(const WordApp());'));
      expect(mainSource, isNot(contains("import 'pages/")));
      expect(bootstrapSource, isNot(contains("import '../pages/")));
      expect(bootstrapSource, isNot(contains('MaterialApp')));
      expect(appSource, contains('AppRouter.buildPage(settings)'));
      expect(appSource, contains('buildAccountFeatureScope('));
      expect(appSource, contains('buildLearningFeatureScope('));
      expect(appSource, contains('buildSettingsFeatureScope('));
      expect(appSource, isNot(contains("import '../state/learning_state.dart';")));
      expect(appSource, isNot(contains("import '../features/learning/application/")));
    });

    test('学习功能域装配将正式调度、评分端口和遗留队列兼容状态连接在一起', () {
      final providersSource = File('lib/features/learning/presentation/learning_feature_providers.dart')
          .readAsStringSync();

      expect(providersSource, contains('ReviewScheduleRepository'));
      expect(providersSource, contains('ReviewRatingWriter(writeRating: schedule.rateWord)'));
      expect(providersSource, contains('LearningSessionState'));
      expect(providersSource, contains('LearningFavoritesState'));
      expect(providersSource, contains('LearningMasteredState'));
      expect(providersSource, contains('LearningQueueState'));
      expect(providersSource, contains('ReviewQueueState'));
      expect(providersSource, isNot(contains('legacy.rateReviewWord')));
      expect(providersSource, isNot(contains('LearningState(')));
    });

    test('遗留学习外观已删除，专用会话保持唯一的可变队列和 Leitner 实现', () {
      final sessionSource = File('lib/features/learning/presentation/learning_session_state.dart').readAsStringSync();

      expect(File('lib/state/learning_state.dart').existsSync(), isFalse);
      expect(sessionSource, contains('LeitnerCardEngine'));
      expect(sessionSource, contains('Future<void> rate(FsrsRating rating)'));
    });

    test('旧练习会话栈已删除，学习页面只依赖专用会话与各自的事实状态', () {
      const migratedPages = [
        'lib/pages/book_words_page.dart',
        'lib/pages/immersive_swipe_page.dart',
        'lib/pages/learn_page.dart',
        'lib/pages/spell_session_page.dart',
        'lib/pages/word_machine_page.dart',
        'lib/screens/home_screen.dart',
        'lib/screens/learn_session.dart',
      ];
      final sessionSource = File('lib/features/learning/presentation/learning_session_state.dart').readAsStringSync();

      expect(File('lib/state/learn_state.dart').existsSync(), isFalse);
      expect(File('lib/services/learn_service.dart').existsSync(), isFalse);
      expect(File('lib/services/learn_service_impl.dart').existsSync(), isFalse);
      expect(File('lib/modules/learn/learn_module.dart').existsSync(), isFalse);
      for (final path in migratedPages) {
        final source = File(path).readAsStringSync();
        expect(source, contains('LearningSessionState'), reason: '$path 应使用专用学习会话');
        expect(source, isNot(contains('LearnState')), reason: '$path 不应回流旧练习状态');
      }
      expect(sessionSource, contains('List.unmodifiable(_queue)'));
      expect(sessionSource, contains('void exitLearning()'));
    });

    test('设置功能域拥有学习偏好，设置页不再保留可丢失的本地偏好副本', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final settingsPageSource = File('lib/pages/settings_page.dart').readAsStringSync();
      final locatorSource = File('lib/core/di/service_locator.dart').readAsStringSync();

      expect(File('lib/state/settings_state.dart').existsSync(), isFalse);
      expect(appSource, contains('buildSettingsFeatureScope('));
      expect(settingsPageSource, contains('LearningPreferencesState'));
      expect(settingsPageSource, isNot(contains('SettingsState')));
      expect(settingsPageSource, isNot(contains('TODO: persist to SharedPreferences')));
      expect(locatorSource, isNot(contains('SettingsState')));
    });

    test('遗留复习会话栈已删除，功能域装配不再注册旧状态或服务', () {
      final locatorSource = File('lib/core/di/service_locator.dart').readAsStringSync();
      final providersSource = File('lib/features/learning/presentation/learning_feature_providers.dart')
          .readAsStringSync();

      expect(File('lib/state/review_state.dart').existsSync(), isFalse);
      expect(File('lib/services/review_service.dart').existsSync(), isFalse);
      expect(File('lib/services/review_service_impl.dart').existsSync(), isFalse);
      expect(locatorSource, isNot(contains('ReviewState')));
      expect(locatorSource, isNot(contains('ReviewService')));
      expect(providersSource, isNot(contains('ReviewState')));
    });
  });

  group('正式复习禁止依赖', () {
    test('路由页面不回流会话算法、遗留聚合状态或服务定位器', () {
      final pageSource = File('lib/pages/review_page.dart').readAsStringSync();

      expect(pageSource, isNot(contains('LearningState')));
      expect(pageSource, isNot(contains('SuperMemoryEngine')));
      expect(pageSource, isNot(contains('ReviewQueueReader')));
      expect(pageSource, isNot(contains('ChoiceGenerator')));
      expect(pageSource, isNot(contains('sl<AudioService>()')));
    });

    test('展示组件不读取会话状态，评分执行器不依赖页面', () {
      const widgetFiles = [
        'lib/features/learning/presentation/widgets/formal_review_session_layout.dart',
        'lib/features/learning/presentation/widgets/formal_review_header.dart',
        'lib/features/learning/presentation/widgets/formal_review_question.dart',
      ];
      final executorSource = File('lib/features/learning/application/review_session_rating_executor.dart')
          .readAsStringSync();

      for (final path in widgetFiles) {
        expect(File(path).readAsStringSync(), isNot(contains('ReviewSessionState')), reason: '$path 不应读取会话状态');
      }
      expect(executorSource, isNot(contains("import '../../../pages/")));
      expect(executorSource, isNot(contains('BuildContext')));
    });

    test('遗留深链不会重新实例化或保留旧复习会话实现', () {
      final learningRoutesSource = File('lib/core/router/learning_routes.dart').readAsStringSync();

      expect(File('lib/screens/review_session.dart').existsSync(), isFalse);
      expect(learningRoutesSource, isNot(contains("import '../../screens/review_session.dart';")));
      expect(learningRoutesSource, isNot(contains('return const ReviewSession();')));
    });
  });
}
