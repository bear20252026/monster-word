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
      expect(appSource, contains('buildWordAudioScope('));
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
        'lib/features/learning/presentation/immersive_swipe_page.dart',
        'lib/features/learning/presentation/learn_page.dart',
        'lib/features/learning/presentation/spell_session_page.dart',
        'lib/features/learning/presentation/word_machine_page.dart',
        'lib/features/learning/presentation/home_screen.dart',
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

    test('词书功能域已垂直化，词单页只依赖词书事实状态与端口', () {
      final featurePage = File('lib/features/book/presentation/book_words_page.dart').readAsStringSync();
      final stateSource = File('lib/features/book/presentation/book_state.dart').readAsStringSync();

      expect(featurePage, contains('BookState'), reason: '词单页应通过词书状态消费数据');
      expect(featurePage, isNot(contains('RepositoryBookCatalogReader')), reason: '词单页不应直连仓库适配器');
      expect(featurePage, isNot(contains('LearnState')));
      expect(stateSource, isNot(contains('sl<')), reason: '词书状态不应直连服务定位器');
    });

    test('账户资料功能域拥有展示与编辑快照，资料页面不再直连用户服务', () {
      const profileConsumers = [
        'lib/features/account/presentation/account_info_page.dart',
        'lib/features/account/presentation/user_info_manage_page.dart',
        'lib/features/account/presentation/my_space_page.dart',
        'lib/features/settings/presentation/profile_screen.dart',
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

    test('单词音频为应用级共享能力（core），各功能经共享状态消费、不直连音频服务', () {
      const audioConsumers = [
        'lib/features/dictionary/presentation/dictionary_page.dart',
        'lib/features/learning/presentation/learn_page.dart',
        'lib/features/search/presentation/search_page.dart',
        'lib/features/learning/presentation/spell_check_page.dart',
        'lib/features/learning/presentation/spell_session_page.dart',
        'lib/features/dictionary/presentation/word_detail_page.dart',
      ];
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final locatorSource = File('lib/app/service_locator.dart').readAsStringSync();

      expect(File('lib/state/player_state.dart').existsSync(), isFalse);
      expect(appSource, contains('buildWordAudioScope('));
      expect(locatorSource, isNot(contains('PlayerState')));
      for (final path in audioConsumers) {
        final source = File(path).readAsStringSync();
        expect(source, contains('AudioPlaybackState'), reason: '$path 应使用共享单词音频状态');
        expect(source, isNot(contains('sl<AudioService>')), reason: '$path 不应直连音频服务');
        expect(source, isNot(contains('features/player/')), reason: '$path 不应 import player 功能域内部');
      }
    });

    test('无消费者的统计栈已删除，应用根不再装配平行统计状态', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final locatorSource = File('lib/app/service_locator.dart').readAsStringSync();

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
      // 页面逻辑已迁入 feature，断言指向 feature 内部页
      final settingsPageSource = File('lib/features/settings/presentation/settings_page.dart').readAsStringSync();
      final locatorSource = File('lib/app/service_locator.dart').readAsStringSync();

      expect(File('lib/state/settings_state.dart').existsSync(), isFalse);
      expect(appSource, contains('buildSettingsFeatureScope('));
      expect(settingsPageSource, contains('LearningPreferencesState'));
      expect(settingsPageSource, isNot(contains('SettingsState')));
      expect(settingsPageSource, isNot(contains('TODO: persist to SharedPreferences')));
      expect(locatorSource, isNot(contains('SettingsState')));
    });

    test('设置功能域已垂直化，页面迁入 feature', () {
      final featureSource = File('lib/features/settings/presentation/settings_page.dart').readAsStringSync();
      expect(featureSource, contains('class SettingsPage'));
      expect(featureSource, contains("routeName = '/settings'"));
    });

    test('遗留复习会话栈已删除，功能域装配不再注册旧状态或服务', () {
      final locatorSource = File('lib/app/service_locator.dart').readAsStringSync();
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
      final pageSource = File('lib/features/dictionary/presentation/word_detail_page.dart').readAsStringSync();
      // 2026-08-30 拆分后，笔记/例句收藏的实际使用点在 word_detail/ 子目录
      final notesSectionSource = File('lib/features/dictionary/presentation/word_detail/word_detail_notes_section.dart')
          .readAsStringSync();
      final exampleTileSource = File('lib/features/dictionary/presentation/word_detail/word_detail_example_tile.dart')
          .readAsStringSync();
      final providersSource = File('lib/features/word_browse/presentation/word_browse_feature_providers.dart')
          .readAsStringSync();

      expect(appSource, contains('buildWordBrowseFeatureScope('));
      expect(File('lib/features/word_browse/application/word_notes_store.dart').existsSync(), isTrue);
      expect(File('lib/features/word_browse/application/sentence_favorites_store.dart').existsSync(), isTrue);
      expect(providersSource, contains('RepositoryWordNotesStore'));
      expect(providersSource, contains('RepositorySentenceFavoritesStore'));
      expect(notesSectionSource, contains('WordNotesStore'));
      expect(exampleTileSource, contains('SentenceFavoritesStore'));
      expect(pageSource, isNot(contains('sl<')));
      expect(pageSource, isNot(contains('NoteRepository')));
      expect(pageSource, isNot(contains('FavRepository')));
    });

    test('考试速刷页通过 QuickReviewWordReader 读取词源', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final pageSource = File('lib/features/quick_review/presentation/exam_quick_review_page.dart').readAsStringSync();
      final providersSource = File('lib/features/quick_review/presentation/quick_review_feature_providers.dart')
          .readAsStringSync();

      expect(appSource, contains('buildQuickReviewFeatureScope('));
      expect(File('lib/features/quick_review/application/quick_review_word_reader.dart').existsSync(), isTrue);
      expect(providersSource, contains('RepositoryQuickReviewWordReader'));
      expect(pageSource, contains('QuickReviewWordReader'));
      expect(pageSource, isNot(contains('WordRepository')));
      expect(pageSource, isNot(contains('sl<')));
    });

    test('词语导出页通过 BookWordListReader 读取词书单词', () {
      final pageSource = File('lib/features/book/presentation/word_export_page.dart').readAsStringSync();

      expect(pageSource, contains('BookWordListReader'));
      expect(pageSource, isNot(contains('LearningQueueRepository')));
      expect(pageSource, isNot(contains('WordRepository')));
      expect(pageSource, isNot(contains('sl<')));
    });

    test('词典页通过 DictionaryContentReader 读取扩展内容', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final featurePageSource = File('lib/features/dictionary/presentation/dictionary_page.dart').readAsStringSync();
      final providersSource = File('lib/features/dictionary/presentation/dictionary_feature_providers.dart')
          .readAsStringSync();

      expect(appSource, contains('buildDictionaryFeatureScope('));
      expect(File('lib/features/dictionary/application/dictionary_content_reader.dart').existsSync(), isTrue);
      expect(providersSource, contains('ServiceDictionaryContentReader'));
      expect(featurePageSource, contains('DictionaryDetailState'));
      expect(featurePageSource, isNot(contains('DictionaryService')));
      // 四层齐全
      expect(Directory('lib/features/dictionary/domain').existsSync(), isTrue);
      expect(Directory('lib/features/dictionary/data').existsSync(), isTrue);
      expect(Directory('lib/features/dictionary/presentation').existsSync(), isTrue);
    });

    test('签到历史页通过 CheckInHistoryReader 读取数据', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final pageSource = File('lib/features/checkin/presentation/check_in_history_page.dart').readAsStringSync();
      final providersSource = File('lib/features/checkin/presentation/check_in_feature_providers.dart')
          .readAsStringSync();

      expect(appSource, contains('buildCheckInFeatureScope('));
      expect(File('lib/features/checkin/application/check_in_history_reader.dart').existsSync(), isTrue);
      // 签到单一事实来源：适配器消费上游 ScareCoinStore 端口，禁止经服务定位器或自建持久化。
      expect(providersSource, contains('context.read<ScareCoinStore>()'));
      expect(providersSource, isNot(contains('service_locator')));
      expect(File('lib/features/checkin/data/checkin_service.dart').existsSync(), isFalse);
      expect(pageSource, contains('CheckInHistoryReader'));
      expect(pageSource, isNot(contains('sl<')));
      expect(pageSource, isNot(contains('CheckInService')));
    });

    test('句库页面通过例句收藏端口访问列表和删除', () {
      final pageSource = File('lib/features/content/presentation/my_fav_sentence_page.dart').readAsStringSync();

      expect(pageSource, contains('SentenceFavoritesStore'));
      expect(pageSource, isNot(contains('sl<')));
      expect(pageSource, isNot(contains('FavRepository')));
      expect(pageSource, isNot(contains('getFavoriteSentences')));
      expect(pageSource, isNot(contains('removeFavoriteSentence')));
    });

    test('搜索页通过搜索功能域端口访问查询与历史记录', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final pageSource = File('lib/features/search/presentation/search_page.dart').readAsStringSync();
      final providersSource = File('lib/features/search/presentation/search_feature_providers.dart').readAsStringSync();

      expect(appSource, contains('buildSearchFeatureScope('));
      expect(File('lib/features/search/application/word_search_reader.dart').existsSync(), isTrue);
      expect(File('lib/features/search/application/search_history_store.dart').existsSync(), isTrue);
      expect(providersSource, contains('RepositoryWordSearchReader'));
      expect(pageSource, contains('WordSearchReader'));
      expect(pageSource, contains('SearchHistoryStore'));
      expect(pageSource, isNot(contains('sl<')));
      expect(pageSource, isNot(contains('AppPreferences')));
      expect(pageSource, isNot(contains('WordRepository')));
    });

    test('掌握状态分离读取端口与写入仓储', () {
      final stateSource = File('lib/features/learning/presentation/learning_mastered_state.dart').readAsStringSync();
      expect(stateSource, contains('MasteredWordsReader'));
      expect(stateSource, contains('MasteredWriterPort'));
      expect(stateSource, contains('_masteredWordsReader.loadTexts()'));
      expect(stateSource, contains('_writerPort.toggleMastered'));
      expect(stateSource, isNot(contains('_masteredRepository.getMasteredWords')));
    });

    test('生词本状态分离读取端口与写入仓储', () {
      final stateSource = File('lib/features/learning/presentation/new_words_state.dart').readAsStringSync();
      expect(stateSource, contains('NewWordsReader'));
      expect(stateSource, contains('NewWordsWriterPort'));
      expect(stateSource, contains('_newWordsReader.loadWords()'));
      expect(stateSource, contains('_writerPort.toggleNewWord'));
      expect(stateSource, contains('_writerPort.removeNewWord'));
      expect(stateSource, isNot(contains('_newWordRepository.getNewWords')));
    });

    test('学习词表读取端口隔离基础仓储依赖', () {
      final masteredPort = File('lib/features/learning/application/mastered_words_reader.dart').readAsStringSync();
      final newWordsPort = File('lib/features/learning/application/new_words_reader.dart').readAsStringSync();
      final reviewQueuePort = File('lib/features/learning/application/review_queue_reader.dart').readAsStringSync();
      final masteredAdapter = File('lib/features/learning/data/repository_mastered_words_reader.dart')
          .readAsStringSync();
      final newWordsAdapter = File('lib/features/learning/data/repository_new_words_reader.dart').readAsStringSync();
      final reviewQueueAdapter = File('lib/features/learning/data/repository_review_queue_reader.dart')
          .readAsStringSync();

      expect(masteredPort, contains('abstract interface class MasteredWordsReader'));
      expect(newWordsPort, contains('abstract interface class NewWordsReader'));
      expect(reviewQueuePort, contains('abstract interface class ReviewQueueReader'));
      for (final source in [masteredPort, newWordsPort, reviewQueuePort]) {
        expect(source, isNot(contains('repositories/')));
        expect(source, isNot(contains('service_locator')));
        expect(source, isNot(contains('SharedPreferences')));
      }
      expect(masteredAdapter, contains('MasteredRepository'));
      expect(newWordsAdapter, contains('NewWordRepository'));
      expect(reviewQueueAdapter, contains('WordRepository'));
    });

    test('词书入口通过 BookCatalogReader 访问目录', () {
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final selectPageSource = File('lib/features/book/presentation/lib_select_page.dart').readAsStringSync();
      final wordsPageSource = File('lib/features/book/presentation/book_words_page.dart').readAsStringSync();
      final extensiveModeSource = File('lib/features/book/presentation/extensive_model_select_page.dart')
          .readAsStringSync();
      final homeSource = File('lib/features/learning/presentation/home_screen.dart').readAsStringSync();
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
      expect(providersSource, contains('RepositoryBookCatalogReader'));
      expect(selectPageSource, contains('BookWordListReader'));
      expect(extensiveModeSource, contains('BookWordListReader'));
      for (final source in [selectPageSource, homeSource]) {
        expect(source, contains('BookCatalogReader'));
        expect(source, isNot(contains('sl<')));
        expect(source, isNot(contains('BookRepository')));
      }
      expect(wordsPageSource, contains('BookState'), reason: '词单页消费词书状态而非直连仓库');
      expect(wordsPageSource, isNot(contains('sl<')));
      expect(wordsPageSource, isNot(contains('BookRepository')));
      for (final source in [selectPageSource, extensiveModeSource]) {
        expect(source, isNot(contains('LearningQueueRepository')));
        expect(source, isNot(contains('learning_queue_repository.dart')));
      }
    });
  });

  group('尖叫币功能域边界', () {
    test('尖叫币页面和组件不持有本地账本实现', () {
      final portSource = File('lib/features/scare_coin/application/scare_coin_store.dart').readAsStringSync();
      final adapterSource = File('lib/features/scare_coin/data/preferences_scare_coin_store.dart').readAsStringSync();
      final providerSource = File('lib/features/scare_coin/presentation/scare_coin_feature_providers.dart')
          .readAsStringSync();
      final appSource = File('lib/app/app.dart').readAsStringSync();
      final pageSource = File('lib/features/scare_coin/presentation/scare_coin_history_page.dart').readAsStringSync();
      final calendarSource = File('lib/widgets/spring_check_in_calendar.dart').readAsStringSync();
      // A5 收口后 profile/my_space 的卡片消费已上收至共享组件（唯一持有 ScareCoinStore 消费）。
      final cardsSource = File('lib/widgets/scare_coin_summary_cards.dart').readAsStringSync();
      final dashboardSource = File('lib/features/learning/presentation/dashboard_page.dart').readAsStringSync();

      expect(portSource, contains('abstract interface class ScareCoinStore'));
      expect(adapterSource, contains('implements ScareCoinStore'));
      expect(adapterSource, contains('SharedPreferences'));
      expect(providerSource, contains('PreferencesScareCoinStore'));
      expect(appSource, contains('buildScareCoinFeatureScope('));
      // 回归：ScareCoinFeatureScope 必须先于 CheckInFeatureScope 建立（即 scare_coin 作用域
      // 是 checkin 作用域的祖先），否则 checkin 页面的 context.read<ScareCoinStore>() 会
      // ProviderNotFound（P0-2 已修复，此断言锁定嵌套顺序防回归）。
      final scareCoinScopeIdx = appSource.indexOf('buildScareCoinFeatureScope(');
      final checkInScopeIdx = appSource.indexOf('buildCheckInFeatureScope(');
      expect(scareCoinScopeIdx, greaterThan(-1));
      expect(checkInScopeIdx, greaterThan(-1));
      expect(scareCoinScopeIdx, lessThan(checkInScopeIdx));
      for (final source in [pageSource, calendarSource, cardsSource, dashboardSource]) {
        expect(source, contains('ScareCoinStore'));
        expect(source, isNot(contains('ScareCoinLedger')));
        expect(source, isNot(contains('SharedPreferences')));
        expect(source, isNot(contains('service_locator')));
      }
    });

    test('A5 尖叫币/装备卡片单一事实来源——共享组件唯一持有，页面零双写', () {
      // 背景：my_space_page 与 profile_screen 此前各自私有实现 _CoinCard/_EquipCard，
      // UI 与行为已漂移（裸 Container vs MwCard、字符串路由 vs RouteNames、装备数
      // 规则 1+(redeemed>0)+(streak>0) 双写、装备徽章两套配色）。v2.7.41 收口至
      // lib/widgets/scare_coin_summary_cards.dart；本测试锁定收口成果防双写复发。
      final cardsSource = File('lib/widgets/scare_coin_summary_cards.dart').readAsStringSync();
      final mySpaceSource = File('lib/features/account/presentation/my_space_page.dart').readAsStringSync();
      final profileSource = File('lib/features/settings/presentation/profile_screen.dart').readAsStringSync();

      // 共享组件是唯一持有方：双卡类 + 双路由常量 + 装备数规则仅写一遍
      expect(cardsSource, contains('class ScareCoinCard'));
      expect(cardsSource, contains('class EquipCard'));
      expect(cardsSource, contains('RouteNames.scareCoinHistory'));
      expect(cardsSource, contains('RouteNames.myEquip'));
      expect(cardsSource, contains('AppPreferences.equipRackCount'));
      const ownedRule = '1 + (redeemedCount > 0 ? 1 : 0) + ((snap.data ?? 0) > 0 ? 1 : 0)';
      expect(ownedRule.allMatches(cardsSource).length, 1, reason: '装备数规则只能写一遍');

      // 两页面零双写：不定义私有卡片类、不算装备数、不写死字符串路由
      for (final entry in {'my_space_page.dart': mySpaceSource, 'profile_screen.dart': profileSource}.entries) {
        expect(entry.value, isNot(contains('class _CoinCard')), reason: '${entry.key} 不得再私有实现卡片');
        expect(entry.value, isNot(contains('class _EquipCard')), reason: '${entry.key} 不得再私有实现卡片');
        expect(entry.value, contains('ScareCoinCard('), reason: '${entry.key} 应消费共享组件');
        expect(entry.value, contains('EquipCard('), reason: '${entry.key} 应消费共享组件');
        expect(entry.value, isNot(contains('AppPreferences.equipRackCount')), reason: '${entry.key} 不得重写装备数规则');
        expect(entry.value, isNot(contains("'/scare_coin_history'")), reason: '${entry.key} 不得使用字符串路由');
      }
    });
  });

  group('Provider scope 嵌套全序锁定（REG-ARCH-003）', () {
    test('app.dart 12 层 scope 必须保持注释 [1]~[12] 的 DAG 链序', () {
      // 背景：app.dart 的 scope 嵌套顺序是全库 Provider 可达性的根基（learning 被跨模块
      // 消费 189 处），此前仅 ScareCoin→CheckIn 一对有断言（复审 A4/H3），其余层序靠
      // 注释维护——任何调整都可能编译期静默、运行时 ProviderNotFound。
      // 本测试锁定完整链序；如需调整嵌套顺序，必须连同本测试与 app.dart 注释一起修改，
      // 并逐页面验证 context.read 依赖方向。
      final appSource = File('lib/app/app.dart').readAsStringSync();
      const chainOrder = <String>[
        'buildWordAudioScope(', // [1] WordAudio
        'buildAccountFeatureScope(', // [2] Account
        'buildLearningFeatureScope(', // [3] Learning
        'buildSettingsFeatureScope(', // [4] Settings
        'buildSearchFeatureScope(', // [5] Search
        'buildQuickReviewFeatureScope(', // [6] QuickReview
        'buildBookFeatureScope(', // [7] Book
        'buildScareCoinFeatureScope(', // [8] ScareCoin
        'buildCheckInFeatureScope(', // [9] CheckIn
        'buildDictionaryFeatureScope(', // [10] Dictionary
        'buildWordBrowseFeatureScope(', // [11] WordBrowse
        'ChangeNotifierProvider(create: (_) => SkinSystem())', // [12] MultiProvider（皮肤/墙纸）
      ];
      var prevIdx = -1;
      for (final marker in chainOrder) {
        final idx = appSource.indexOf(marker);
        expect(idx, greaterThan(-1), reason: 'app.dart 缺少 scope 标记：$marker（结构被改动？）');
        expect(
          idx,
          greaterThan(prevIdx),
          reason: 'scope 嵌套顺序被调整：$marker 必须保持 app.dart 注释 [1]~[12] 的 DAG 链序（详见 app.dart ScopeOrder 注释）',
        );
        prevIdx = idx;
      }
    });
  });

  group('正式复习禁止依赖', () {
    test('路由页面不回流会话算法、遗留聚合状态或服务定位器', () {
      final pageSource = File('lib/features/learning/presentation/review_page.dart').readAsStringSync();

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
      final wordDetailSource = File('lib/features/dictionary/presentation/word_detail_page.dart').readAsStringSync();
      final dialogSource = File('lib/features/learning/presentation/review_dialog.dart').readAsStringSync();
      final statisticsSource = File('lib/features/learning/presentation/learning_statistics_state.dart')
          .readAsStringSync();
      final wordListsSource = File('lib/features/learning/presentation/learning_queue_word_lists_state.dart')
          .readAsStringSync();
      final reviewQueueSource = File('lib/features/learning/presentation/review_queue_state.dart').readAsStringSync();

      expect(portSource, contains('abstract class ReviewScheduleReader extends ChangeNotifier'));
      expect(adapterSource, contains('extends ReviewScheduleReader'));
      expect(providerSource, contains('RepositoryReviewScheduleReader'));
      for (final source in [wordDetailSource, dialogSource, statisticsSource, wordListsSource, reviewQueueSource]) {
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
      final learningRoutesSource = File('lib/app/router/learning_routes.dart').readAsStringSync();

      expect(File('lib/screens/review_session.dart').existsSync(), isFalse);
      expect(learningRoutesSource, isNot(contains("import '../../screens/review_session.dart';")));
      expect(learningRoutesSource, isNot(contains('return const ReviewSession();')));
    });

    test('组合根位于 app 层，core 不反向依赖 feature（REG-ARCH-002）', () {
      // service_locator（get_it 组合根）已上移 app/；core/di 目录不复存在。
      expect(Directory('lib/core/di').existsSync(), isFalse);
      expect(File('lib/app/service_locator.dart').existsSync(), isTrue);
      expect(File('lib/core/audio/word_audio_scope.dart').readAsStringSync(), isNot(contains('service_locator')));

      // 路由装配边界（组合根另一半）已上移 app/router/（v2.7.44）；core/router 不复存在。
      expect(Directory('lib/core/router').existsSync(), isFalse);
      expect(File('lib/app/router/app_router.dart').existsSync(), isTrue);

      // core 层禁止 import 任何 feature 包（路由装配边界已迁出 core，无需再豁免）。
      final offenders = <String>[];
      for (final entity in Directory('lib/core').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        if (source.contains("import 'package:word_app/features/")) offenders.add(entity.path);
      }
      expect(offenders, isEmpty, reason: 'core 不得反向依赖 features：$offenders');
    });
  });
}
