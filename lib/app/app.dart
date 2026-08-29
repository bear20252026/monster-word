import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/audio/word_audio_scope.dart';
import 'package:word_app/core/router/app_router.dart';
import 'package:word_app/core/router/global_nav_history_bar.dart';
import 'package:word_app/core/router/navigation_history.dart';
import 'package:word_app/features/account/presentation/account_feature_providers.dart';
import 'package:word_app/features/book/presentation/book_feature_providers.dart';
import 'package:word_app/features/checkin/presentation/check_in_feature_providers.dart';
import 'package:word_app/features/dictionary/presentation/dictionary_feature_providers.dart';
import 'package:word_app/features/learning/presentation/learning_feature_providers.dart';
import 'package:word_app/features/quick_review/presentation/quick_review_feature_providers.dart';
import 'package:word_app/features/settings/presentation/settings_feature_providers.dart';
import 'package:word_app/features/search/presentation/search_feature_providers.dart';
import 'package:word_app/features/scare_coin/presentation/scare_coin_feature_providers.dart';
import 'package:word_app/features/word_browse/presentation/word_browse_feature_providers.dart';
import 'package:word_app/features/account/presentation/splash_page.dart';
import 'package:word_app/features/book/presentation/lib_select_page.dart';
import 'package:word_app/screens/home_screen.dart';
import 'package:word_app/screens/profile_screen.dart';
import 'package:word_app/app/main_shell.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/theme/wallpaper_state.dart';
import 'package:word_app/utils/screen_utils.dart';
import 'package:word_app/widgets/adaptive_scale.dart';
import 'package:word_app/widgets/fluid_cursor.dart';

/// 应用根组件。
///
/// 该组件只负责全局状态注入、主题、首页 Shell 与路由装配。
/// 平台与基础设施初始化由 [bootstrapApp] 负责，页面构建由 [AppRouter] 负责。
class WordApp extends StatelessWidget {
  const WordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return buildWordAudioScope(
      // [1] WordAudio — core/audio 音频会话/播放态。✅ 被全部下游会话页（learn/review/spell/dictation）消费；无上游 provider 依赖，故放最外。
      child: buildAccountFeatureScope(
        // [2] Account — AppSessionState(implements AppSessionController) + AccountProfile。✅ settings(更多设置)经 AppSessionController.logout 消费；Splash 登录检查依赖。无上游依赖。
        child: buildLearningFeatureScope(
          // [3] Learning — LearningSession/LearningQueue*/Review*/Favorites/NewWords/LearningProgressReader。✅ 是 book(G3.2)、search(FavoritesAccessor)、词书会话的上游渠道；已核实【不依赖 Account】，置于 Account 内层为 DAG 链序选择，非依赖驱动。
          child: buildSettingsFeatureScope(
            // [4] Settings — LearningPreferencesState。✅ 消费 Account(logout)；被 profile/school preference 消费。已核实【不依赖 learning feature】，位于 learning 内层为链序选择，非依赖驱动。
            child: buildSearchFeatureScope(
              // [5] Search — WordSearchReader/SearchHistoryStore/ExampleReader/FavoritesAccessor(经 LearningFavoritesStore)。✅ 依赖 learning 祖先(收藏)；无自身上游。
              child: buildQuickReviewFeatureScope(
                // [6] QuickReview — QuickReviewWordReader。仅读词；依赖较浅。
                child: buildBookFeatureScope(
                  // [7] Book — BookCatalogReader/BookWordsReader(book 侧)/BookState。✅ 必须位于 learning 内层：BookState 消费 learning 祖先的 LearningProgressReader + LearningSessionStarter。
                  child: buildScareCoinFeatureScope(
                    // [8] ScareCoin — ScareCoinStore。✅ 是 checkin 的上游渠道；亦被 profile/redemption/日历消费。
                    child: buildCheckInFeatureScope(
                      // [9] CheckIn — CheckInHistoryReader/CheckinStatusReader/CheckinWriter。✅ 消费 [8] ScareCoinStore，故必须在其内层；[8]→[9] 即渠道方向。
                      child: buildDictionaryFeatureScope(
                        // [10] Dictionary — 词典 Reader/Writer。被 word_detail/查词页消费；✅ 已核实【无上游 feature 依赖】。
                        child: buildWordBrowseFeatureScope(
                          // [11] WordBrowse — WordNotesStore/SentenceFavoritesStore。被 word_detail/my_fav 消费；无上游 feature 依赖，最内层 feature scope。
                          child: MultiProvider(
                            // MultiProvider[SkinSystem, WallpaperState] — 主题皮肤/墙纸。被 MaterialApp(_AppLifecycle) 与所有页面消费；位于所有 feature scope 之后（feature 层无法 context.read<SkinSystem>()，当前无此需求，保留）。
                            providers: [
                              ChangeNotifierProvider(create: (_) => SkinSystem()),
                              ChangeNotifierProvider(create: (_) => WallpaperState()),
                            ],
                            child: const _AppLifecycle(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
        final history = NavigationHistoryService.instance;
        return MaterialApp(
          title: 'Monster Word',
          debugShowCheckedModeBanner: false,
          navigatorKey: history.navigatorKey,
          navigatorObservers: [history.observer],
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
              child: SkinProvider(
                skin: skin,
                child: GlobalNavHistoryBar(
                  history: history,
                  child: child!,
                ),
              ),
            );
          },
          // A-1: Splash 复位为真正启动入口 — 品牌动画 → 登录态检查 → 首次引导 → 落地页。
          // SplashPage 内部通过 pushReplacementNamed('/') 进入 _HomeShell，
          // 保证冷启动时品牌/登录/引导流程完整展示。
          home: const AdaptiveScale(child: SplashPage()),
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
