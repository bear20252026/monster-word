import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/service_locator.dart';
import 'package:word_app/core/audio/audio_service.dart';
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
import 'package:word_app/widgets/common/mw_error_boundary.dart';
import 'package:word_app/features/book/presentation/lib_select_page.dart';
import 'package:word_app/features/learning/presentation/home_screen.dart';
import 'package:word_app/features/settings/presentation/profile_screen.dart';
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
      audioService: sl<AudioService>(),
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
                      // [9] CheckIn — CheckInHistoryReader/CheckinStatusReader/CheckinWriter。✅ 适配器直接消费 [8] ScareCoinStore（签到单一事实来源），故必须在其内层；[8]→[9] 即渠道方向。
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
          theme: _buildTheme(skin),
          builder: (context, child) {
            ScreenUtils.init(context);
            installMwErrorBoundary(); // release 全局兜底（debug 走下方 ErrorBoundary）
            return FluidCursorOverlay(
              rippleColor: skin.colors.accent.withValues(alpha: 0.4),
              maxRadius: 60,
              enabled: false,
              child: SkinProvider(
                skin: skin,
                child: GlobalNavHistoryBar(history: history, child: child!),
              ),
            );
          },
          // A-1: Splash 复位为真正启动入口 — 品牌动画 → 登录态检查 → 首次引导 → 落地页。
          // 注意：不能用 home: SplashPage——MaterialApp 中 home 恒占 '/' 路由，
          // 导致 pushReplacementNamed('/') 永远跳回 Splash 而非主页（启动卡死根因）。
          // Splash 改用专属路由 /splash，'/' 明确映射 _HomeShell 主页。
          initialRoute: '/splash',
          onGenerateRoute: _onGenerateRoute,
        );
      },
    );
  }

  /// 全局 Material 主题精修 — 对标 Geist（Vercel）设计语言：
  /// 扁平 + hairline 边框 + 微阴影 + 紧凑字距 + 精致水花反馈。
  /// 数值联动 A 档（skin.colors）与 B 档（skin.design），跟随品牌换肤。
  ThemeData _buildTheme(SkinSystem skin) {
    final c = skin.colors;
    final d = skin.design;
    final isDark = skin.effectiveUiBrightness == Brightness.dark;

    return ThemeData(
      brightness: skin.effectiveUiBrightness,
      // 字体统一（体验审计 P1）：全 app 唯一字体入口。
      // 未选择皮肤字体时默认 Inter（打包资产），token 层不再硬编码 fontFamily，
      // 所有文本（含导航栏/Dock/页面标题）继承此值，消除双字体系统。
      fontFamily: skin.effectiveFontFamily ?? 'Inter',
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
      scaffoldBackgroundColor: c.pageBg,
      colorScheme: ColorScheme.fromSeed(seedColor: c.accent, brightness: skin.effectiveUiBrightness).copyWith(
        primary: c.accent,
        secondary: c.accent,
        surface: c.cardBg,
        surfaceContainerHighest: c.cardBgAlt,
        error: c.danger,
      ),
      // 页面转场：全平台统一 Zoom（现代、克制），替代 Windows 的老式 FadeUpwards
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        },
      ),
      // 字阶：标题紧字距（Geist 式 "tight"），正文暖灰而非纯黑
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: d.typography.hero,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.2,
          color: c.text1,
        ),
        displayMedium: TextStyle(
          fontSize: d.typography.h1,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.8,
          color: c.text1,
        ),
        displaySmall: TextStyle(
          fontSize: d.typography.h2,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: c.text1,
        ),
        headlineMedium: TextStyle(
          fontSize: d.typography.h3,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          color: c.text1,
        ),
        headlineSmall: TextStyle(
          fontSize: d.typography.h4,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: c.text1,
        ),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: c.text1),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text1),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text1),
        bodyLarge: TextStyle(fontSize: d.typography.body, fontWeight: FontWeight.w400, color: c.text1),
        bodyMedium: TextStyle(fontSize: d.typography.bodySm, fontWeight: FontWeight.w400, color: c.text2),
        bodySmall: TextStyle(fontSize: d.typography.caption, fontWeight: FontWeight.w400, color: c.text2),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: c.text1),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.text2),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.4, color: c.text3),
      ),
      // 按钮：扁平化（elevation 0），实心按钮主色、次级按钮 hairline 描边
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: isDark ? c.pageBg : Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(d.radius.control)),
          textStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            color: isDark ? c.pageBg : Colors.white,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text1,
          elevation: 0,
          minimumSize: const Size(64, 44),
          side: BorderSide(color: c.divider, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(d.radius.control)),
          textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      // 输入框：filled + hairline，聚焦主色 1.2px
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.cardBg,
        hintStyle: TextStyle(color: c.text3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(d.radius.control),
          borderSide: BorderSide(color: c.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(d.radius.control),
          borderSide: BorderSide(color: c.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(d.radius.control),
          borderSide: BorderSide(color: c.accent, width: 1.2),
        ),
      ),
      // 卡片/弹层/分割线：hairline 分隔 + 微阴影
      cardTheme: CardThemeData(
        color: c.cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(d.radius.card),
          side: BorderSide(color: c.divider.withValues(alpha: 0.6)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.modalGlassBg,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(d.radius.sheet)),
      ),
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? (isDark ? c.pageBg : Colors.white) : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : c.divider,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.transparent : c.divider,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: c.text1,
        titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: c.text1),
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '/';
    final Widget page;
    switch (name) {
      case '/':
        page = const AdaptiveScale(child: _HomeShell());
      case '/splash':
        page = const AdaptiveScale(child: SplashPage());
      default:
        final resolved = AppRouter.buildPage(settings);
        if (resolved == null) {
          return null;
        }
        page = resolved;
    }
    return AppRouter.buildPageRoute(name, page);
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
