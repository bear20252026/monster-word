import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/di/service_locator.dart';
import '../core/router/app_router.dart';
import '../repositories/fav_repository.dart';
import '../repositories/mastered_repository.dart';
import '../features/learning/application/book_words_reader.dart';
import '../features/learning/application/mastered_words_reader.dart';
import '../features/learning/application/new_words_reader.dart';
import '../features/learning/application/review_audio_player.dart';
import '../features/learning/application/review_queue_reader.dart';
import '../features/learning/application/review_rating_writer.dart';
import '../features/learning/presentation/learning_collections_state.dart';
import '../features/learning/presentation/learning_queue_word_lists_state.dart';
import '../features/learning/presentation/learning_statistics_state.dart';
import '../features/learning/presentation/new_words_state.dart';
import '../features/learning/presentation/review_audio_state.dart';
import '../features/learning/presentation/review_queue_state.dart';
import '../features/learning/presentation/review_session_state.dart';
import '../features/learning/presentation/review_word_actions_state.dart';
import '../pages/lib_select_page.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../shell/main_shell.dart';
import '../state/learn_state.dart';
import '../state/learning_state.dart';
import '../state/player_state.dart';
import '../state/review_state.dart';
import '../state/settings_state.dart';
import '../state/user_stats_state.dart';
import '../state/wallpaper_state.dart';
import '../theme/skin_system.dart';
import '../utils/screen_utils.dart';
import '../widgets/adaptive_scale.dart';
import '../widgets/fluid_cursor.dart';

/// 应用根组件。
///
/// 该组件只负责全局状态注入、主题、首页 Shell 与路由装配。
/// 平台与基础设施初始化由 [bootstrapApp] 负责，页面构建由 [AppRouter] 负责。
class WordApp extends StatelessWidget {
  const WordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 兼容期内保留旧状态；学习模块迁移完成后应删除该 Provider。
        ChangeNotifierProvider(
          create: (_) =>
              LearningState(favRepository: sl<FavRepository>(), masteredRepository: sl<MasteredRepository>()),
        ),
        ChangeNotifierProxyProvider<LearningState, LearningStatisticsState>(
          create: (_) => LearningStatisticsState(),
          update: (_, legacy, statistics) => (statistics ?? LearningStatisticsState())..synchronizeFrom(legacy),
        ),
        ChangeNotifierProxyProvider<LearningState, LearningCollectionsState>(
          create: (_) => LearningCollectionsState(),
          update: (_, legacy, collections) => (collections ?? LearningCollectionsState())..synchronizeFrom(legacy),
        ),
        ChangeNotifierProxyProvider<LearningState, LearningQueueWordListsState>(
          create: (_) => LearningQueueWordListsState(),
          update: (_, legacy, wordLists) => (wordLists ?? LearningQueueWordListsState())..synchronizeFrom(legacy),
        ),
        ChangeNotifierProxyProvider<LearningState, ReviewQueueState>(
          create: (_) => ReviewQueueState(),
          update: (_, legacy, reviewQueue) => (reviewQueue ?? ReviewQueueState())..synchronizeFrom(legacy),
        ),
        ProxyProvider<LearningState, ReviewRatingWriter>(
          update: (_, legacy, _) => ReviewRatingWriter(writeRating: legacy.rateReviewWord),
        ),
        ChangeNotifierProxyProvider<ReviewRatingWriter, ReviewSessionState>(
          create: (context) => ReviewSessionState(
            queueReader: sl<ReviewQueueReader>(),
            ratingWriter: context.read<ReviewRatingWriter>(),
          ),
          update: (_, ratingWriter, session) =>
              (session ?? ReviewSessionState(queueReader: sl<ReviewQueueReader>(), ratingWriter: ratingWriter))
                ..updateRatingWriter(ratingWriter),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              ReviewWordActionsState(favRepository: sl<FavRepository>(), masteredRepository: sl<MasteredRepository>())
                ..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => ReviewAudioState(audioPlayer: sl<ReviewAudioPlayer>())),
        Provider<BookWordsReader>.value(value: sl<BookWordsReader>()),
        Provider<MasteredWordsReader>.value(value: sl<MasteredWordsReader>()),
        Provider<NewWordsReader>.value(value: sl<NewWordsReader>()),
        Provider<ReviewQueueReader>.value(value: sl<ReviewQueueReader>()),
        ChangeNotifierProvider(create: (_) => sl<NewWordsState>()..initialize()),
        ChangeNotifierProvider(create: (_) => sl<LearnState>()),
        ChangeNotifierProvider(create: (_) => sl<ReviewState>()),
        ChangeNotifierProvider(create: (_) => sl<UserStatsState>()),
        ChangeNotifierProvider(create: (_) => sl<SettingsState>()..init()),
        ChangeNotifierProvider(create: (_) => sl<PlayerState>()),
        ChangeNotifierProvider(create: (_) => SkinSystem()),
        ChangeNotifierProvider(create: (_) => WallpaperState()),
      ],
      child: const _AppLifecycle(),
    );
  }
}

class _AppLifecycle extends StatefulWidget {
  const _AppLifecycle();

  @override
  State<_AppLifecycle> createState() => _AppLifecycleState();
}

class _AppLifecycleState extends State<_AppLifecycle> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged = _syncSystemBrightness;
  }

  @override
  void didChangePlatformBrightness() {
    _syncSystemBrightness();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged = null;
    super.dispose();
  }

  void _syncSystemBrightness() {
    context.read<SkinSystem>().updateSystemBrightness(WidgetsBinding.instance.platformDispatcher.platformBrightness);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SkinSystem>(
      builder: (context, skin, _) {
        return MaterialApp(
          title: 'Monster Word',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: skin.effectiveUiBrightness,
            fontFamily: skin.effectiveFontFamily,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
              },
            ),
            scaffoldBackgroundColor: skin.colors.pageBg,
            colorScheme: ColorScheme.fromSeed(seedColor: skin.colors.accent, brightness: skin.effectiveUiBrightness),
            useMaterial3: true,
          ),
          builder: (context, child) {
            ScreenUtils.init(context);
            return FluidCursorOverlay(
              rippleColor: skin.colors.accent.withValues(alpha: 0.4),
              maxRadius: 60,
              enabled: false,
              child: SkinProvider(skin: skin, child: child!),
            );
          },
          home: const AdaptiveScale(child: _HomeShell()),
          onGenerateRoute: _onGenerateRoute,
        );
      },
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final page = settings.name == '/' ? const _HomeShell() : AppRouter.buildPage(settings);
    if (page == null) {
      return null;
    }
    return AppRouter.buildPageRoute(settings.name, page);
  }
}

class _HomeShell extends StatelessWidget {
  const _HomeShell();

  @override
  Widget build(BuildContext context) {
    return MainShell(
      tabs: [
        TabDef(id: 'learn', label: '学习', icon: Icons.auto_stories_outlined, builder: (_) => const HomeScreen()),
        TabDef(id: 'course', label: '课程', icon: Icons.school_outlined, builder: (_) => const LibSelectPage()),
        TabDef(id: 'settings', label: '设置', icon: Icons.settings_outlined, builder: (_) => const ProfileScreen()),
      ],
    );
  }
}
