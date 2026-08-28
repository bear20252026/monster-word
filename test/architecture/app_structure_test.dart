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
      expect(appSource, contains('buildPlayerFeatureScope('));
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

    test('账户资料功能域拥有展示与编辑快照，资料页面不再直连用户服务', () {
      const profileConsumers = [
        'lib/pages/account_info_page.dart',
        'lib/pages/user_info_manage_page.dart',
        'lib/pages/my_space_page.dart',
        'lib/screens/profile_screen.dart',
      ];
      final providersSource = File('lib/features/account/presentation/account_feature_providers.dart')
          .readAsStringSync();

      expect(providersSource, contains('AccountProfileRepository'));
      expect(providersSource, contains('AccountProfileState'));
      for (final path in profileConsumers) {
        final source = File(path).readAsStringSync();
        expect(source, contains('AccountProfileState'), reason: '$path 应使用账户资料状态');
        expect(source, isNot(contains('sl<UserService>')), reason: '$path 不应直连用户服务定位器');
        expect(source, isNot(contains('getUserInfoSyncBean')), reason: '$path 不应读取同步默认资料');
      }
    });

    test('播放器功能域拥有播放状态，页面不再使用旧状态或直连音频服务', () {
      const audioConsumers = [
        'lib/pages/dictionary_page.dart',
        'lib/pages/learn_page.dart',
        'lib/pages/search_page.dart',
        'lib/pages/spell_check_page.dart',
        'lib/pages/spell_session_page.dart',
        'lib/pages/word_detail_page.dart',
      ];
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final locatorSource = File('lib/core/di/service_locator.dart').readAsStringSync();

      expect(File('lib/state/player_state.dart').existsSync(), isFalse);
      expect(appSource, contains('buildPlayerFeatureScope('));
      expect(locatorSource, isNot(contains('PlayerState')));
      for (final path in audioConsumers) {
        final source = File(path).readAsStringSync();
        expect(source, contains('AudioPlaybackState'), reason: '$path 应使用专用播放器状态');
        expect(source, isNot(contains('sl<AudioService>')), reason: '$path 不应直连音频服务');
      }
    });

    test('无消费者的统计栈已删除，应用根不再装配平行统计状态', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final locatorSource = File('lib/core/di/service_locator.dart').readAsStringSync();

      expect(File('lib/state/user_stats_state.dart').existsSync(), isFalse);
      expect(File('lib/services/stats_service.dart').existsSync(), isFalse);
      expect(File('lib/services/stats_service_impl.dart').existsSync(), isFalse);
      expect(File('lib/repositories/stats_repository.dart').existsSync(), isFalse);
      expect(File('lib/repositories/stats_repository_impl.dart').existsSync(), isFalse);
      expect(appSource, isNot(contains('UserStatsState')));
      expect(locatorSource, isNot(contains('StatsService')));
      expect(locatorSource, isNot(contains('StatsRepository')));
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

  group('词条浏览依赖边界', () {
    test('详情页通过浏览功能域端口读写笔记和例句收藏', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final pageSource = File('lib/pages/word_detail_page.dart').readAsStringSync();
      final providersSource = File('lib/features/word_browse/presentation/word_browse_feature_providers.dart')
          .readAsStringSync();

      expect(appSource, contains('buildWordBrowseFeatureScope('));
      expect(File('lib/features/word_browse/application/word_notes_store.dart').existsSync(), isTrue);
      expect(File('lib/features/word_browse/application/sentence_favorites_store.dart').existsSync(), isTrue);
      expect(providersSource, contains('sl<NoteRepository>()'));
      expect(providersSource, contains('sl<FavRepository>()'));
      expect(pageSource, contains('WordNotesStore'));
      expect(pageSource, contains('SentenceFavoritesStore'));
      expect(pageSource, isNot(contains('sl<')));
      expect(pageSource, isNot(contains('NoteRepository')));
      expect(pageSource, isNot(contains('FavRepository')));
    });

    test('考试速刷页通过 QuickReviewWordReader 读取词源', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final pageSource = File('lib/pages/exam_quick_review_page.dart').readAsStringSync();
      final providersSource = File('lib/features/quick_review/presentation/quick_review_feature_providers.dart')
          .readAsStringSync();

      expect(appSource, contains('buildQuickReviewFeatureScope('));
      expect(File('lib/features/quick_review/application/quick_review_word_reader.dart').existsSync(), isTrue);
      expect(providersSource, contains('sl<WordRepository>()'));
      expect(pageSource, contains('QuickReviewWordReader'));
      expect(pageSource, isNot(contains('WordRepository')));
      expect(pageSource, isNot(contains('sl<')));
    });

    test('词语导出页通过 BookWordsReader 读取词书单词', () {
      final pageSource = File('lib/pages/word_export_page.dart').readAsStringSync();

      expect(pageSource, contains('BookWordsReader'));
      expect(pageSource, isNot(contains('LearningQueueRepository')));
      expect(pageSource, isNot(contains('WordRepository')));
      expect(pageSource, isNot(contains('sl<')));
    });

    test('词典页通过 DictionaryContentReader 读取扩展内容', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final pageSource = File('lib/pages/dictionary_page.dart').readAsStringSync();
      final providersSource = File('lib/features/dictionary/presentation/dictionary_feature_providers.dart')
          .readAsStringSync();

      expect(appSource, contains('buildDictionaryFeatureScope('));
      expect(File('lib/features/dictionary/application/dictionary_content_reader.dart').existsSync(), isTrue);
      expect(providersSource, contains('DictionaryService.instance'));
      expect(pageSource, contains('DictionaryContentReader'));
      expect(pageSource, isNot(contains('DictionaryService')));
    });

    test('签到历史页通过 CheckInHistoryReader 读取数据', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final pageSource = File('lib/pages/check_in_history_page.dart').readAsStringSync();
      final providersSource = File('lib/features/checkin/presentation/check_in_feature_providers.dart')
          .readAsStringSync();

      expect(appSource, contains('buildCheckInFeatureScope('));
      expect(File('lib/features/checkin/application/check_in_history_reader.dart').existsSync(), isTrue);
      expect(providersSource, contains('sl<CheckInService>()'));
      expect(pageSource, contains('CheckInHistoryReader'));
      expect(pageSource, isNot(contains('sl<')));
      expect(pageSource, isNot(contains('CheckInService')));
    });

    test('句库页面通过例句收藏端口访问列表和删除', () {
      final pageSource = File('lib/pages/my_fav_sentence_page.dart').readAsStringSync();

      expect(pageSource, contains('SentenceFavoritesStore'));
      expect(pageSource, isNot(contains('sl<')));
      expect(pageSource, isNot(contains('FavRepository')));
      expect(pageSource, isNot(contains('getFavoriteSentences')));
      expect(pageSource, isNot(contains('removeFavoriteSentence')));
    });

    test('搜索页通过搜索功能域端口访问查询与历史记录', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final pageSource = File('lib/pages/search_page.dart').readAsStringSync();
      final providersSource = File('lib/features/search/presentation/search_feature_providers.dart').readAsStringSync();

      expect(appSource, contains('buildSearchFeatureScope('));
      expect(File('lib/features/search/application/word_search_reader.dart').existsSync(), isTrue);
      expect(File('lib/features/search/application/search_history_store.dart').existsSync(), isTrue);
      expect(providersSource, contains('sl<WordRepository>()'));
      expect(pageSource, contains('WordSearchReader'));
      expect(pageSource, contains('SearchHistoryStore'));
      expect(pageSource, isNot(contains('sl<')));
      expect(pageSource, isNot(contains('AppPreferences')));
      expect(pageSource, isNot(contains('WordRepository')));
    });

    test('词书入口通过 BookCatalogReader 访问目录', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final selectPageSource = File('lib/pages/lib_select_page.dart').readAsStringSync();
      final wordsPageSource = File('lib/pages/book_words_page.dart').readAsStringSync();
      final extensiveModeSource = File('lib/pages/extensive_model_select_page.dart').readAsStringSync();
      final homeSource = File('lib/screens/home_screen.dart').readAsStringSync();
      final providersSource = File('lib/features/book/presentation/book_feature_providers.dart').readAsStringSync();

      expect(appSource, contains('buildBookFeatureScope('));
      expect(File('lib/features/book/application/book_catalog_reader.dart').existsSync(), isTrue);
      final bookWordsPortSource = File('lib/features/learning/application/book_words_reader.dart').readAsStringSync();
      final bookWordsAdapterSource = File('lib/features/learning/data/repository_book_words_reader.dart')
          .readAsStringSync();
      expect(bookWordsPortSource, contains('abstract interface class BookWordsReader'));
      expect(bookWordsPortSource, isNot(contains('WordRepository')));
      expect(bookWordsAdapterSource, contains('implements BookWordsReader'));
      expect(bookWordsAdapterSource, contains('WordRepository'));
      expect(providersSource, contains('sl<BookRepository>()'));
      expect(selectPageSource, contains('BookWordsReader'));
      expect(extensiveModeSource, contains('BookWordsReader'));
      for (final source in [selectPageSource, wordsPageSource, homeSource]) {
        expect(source, contains('BookCatalogReader'));
        expect(source, isNot(contains('sl<')));
        expect(source, isNot(contains('BookRepository')));
      }
      for (final source in [selectPageSource, extensiveModeSource]) {
        expect(source, isNot(contains('LearningQueueRepository')));
        expect(source, isNot(contains('learning_queue_repository.dart')));
      }
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

    test('FSRS 展示页面通过 ReviewScheduleReader 读取只读信息', () {
      final portSource = File('lib/features/learning/application/review_schedule_reader.dart').readAsStringSync();
      final adapterSource = File('lib/features/learning/data/repository_review_schedule_reader.dart')
          .readAsStringSync();
      final providerSource = File('lib/features/learning/presentation/learning_feature_providers.dart')
          .readAsStringSync();
      final wordDetailSource = File('lib/pages/word_detail_page.dart').readAsStringSync();
      final learnSessionSource = File('lib/screens/learn_session.dart').readAsStringSync();
      final dialogSource = File('lib/widgets/review_dialog.dart').readAsStringSync();

      expect(portSource, contains('abstract class ReviewScheduleReader extends ChangeNotifier'));
      expect(adapterSource, contains('extends ReviewScheduleReader'));
      expect(providerSource, contains('RepositoryReviewScheduleReader'));
      for (final source in [wordDetailSource, learnSessionSource, dialogSource]) {
        expect(source, contains('ReviewScheduleReader'));
        expect(source, isNot(contains('ReviewScheduleRepository')));
        expect(source, isNot(contains('review_schedule_repository.dart')));
      }
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
