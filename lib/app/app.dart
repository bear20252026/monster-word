import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/di/service_locator.dart';
import '../core/router/app_router.dart';
import '../features/account/presentation/account_feature_providers.dart';
import '../features/learning/presentation/learning_feature_providers.dart';
import '../features/player/presentation/player_feature_providers.dart';
import '../features/settings/presentation/settings_feature_providers.dart';
import '../pages/lib_select_page.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../shell/main_shell.dart';
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
    return buildAccountFeatureScope(
      child: buildLearningFeatureScope(
        child: buildSettingsFeatureScope(
          child: buildPlayerFeatureScope(
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => SkinSystem()),
                ChangeNotifierProvider(create: (_) => WallpaperState()),
              ],
              child: const _AppLifecycle(),
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
