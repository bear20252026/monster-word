// 由账号4生成
// Monster Word App 入口：接入新设计系统（SkinProvider + MainShell + 三主题）
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'data/wordbook_database.dart';
import 'data/user_database.dart';
import 'player/audio_players.dart';
import 'utils/screen_utils.dart';
import 'pages/dashboard_page.dart';
import 'pages/extensive_model_select_page.dart';
import 'pages/foot_mark_page.dart';
import 'pages/help_page.dart';
import 'pages/learn_page.dart';
import 'pages/lib_select_page.dart';
import 'pages/book_words_page.dart';
import 'pages/linked_me_middle_page.dart';
import 'pages/list_word_listen_page.dart';
import 'pages/login_page.dart';
import 'pages/mastered_words_page.dart';
import 'pages/message_page.dart';
import 'pages/my_equip_page.dart';
import 'pages/my_fav_page.dart';
import 'pages/my_fav_sentence_page.dart';
import 'pages/my_space_page.dart';
import 'pages/my_words_page.dart';
import 'pages/net_diagnosis_page.dart';
import 'pages/new_words_page.dart';
import 'pages/not_learned_words_page.dart';
import 'pages/personal_stereo_page.dart';
import 'pages/play_order_page.dart';
import 'pages/review_page.dart';
import 'pages/reviewing_words_page.dart';
import 'pages/scare_coin_history_page.dart';
import 'pages/search_page.dart';
import 'pages/sentence_detail_page.dart';
import 'pages/sentence_quiz_page.dart';
import 'pages/immersive_swipe_page.dart';
import 'pages/appearance_page.dart';
import 'pages/more_settings_page.dart';
import 'pages/word_machine_page.dart';
import 'pages/my_content_page.dart';
import 'pages/settings_page.dart';
import 'pages/spell_check_page.dart';
import 'pages/spell_session_page.dart';
import 'pages/splash_page.dart';
import 'pages/ui_theme_select_page.dart';
import 'pages/user_info_manage_page.dart';
import 'pages/word_detail_page.dart';
import 'screens/home_screen.dart';
import 'screens/learn_session.dart';
import 'screens/profile_screen.dart';
import 'screens/review_session.dart';
import 'shell/main_shell.dart';
import 'state/learning_state.dart';
import 'state/wallpaper_state.dart';
import 'theme/skin_system.dart';
import 'data/app_preferences.dart';
import 'widgets/adaptive_scale.dart';
import 'widgets/transition_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ===== 全局错误捕获 =====
  // 1) 框架层异常（Widget 构建 / 布局 / 绘制 / 手势回调中抛出）
  FlutterError.onError = (details) {
    debugPrint('[GlobalError] FlutterError: ${details.exception}');
    if (details.stack != null) {
      debugPrint('[GlobalError] Stack:\n${details.stack}');
    }
    // 保留默认处理：调试期红屏 / 测试环境抛错等行为不受影响
    FlutterError.presentError(details);
  };
  // 2) 未捕获的异步与平台层异常（Timer/Future/事件循环），兜底防崩溃
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('[GlobalError] Uncaught: $error');
    debugPrint('[GlobalError] Stack:\n$stack');
    return true; // 标记已处理，避免直接崩溃退出
  };

  // 3) 自定义 Widget 构建异常页面（替代默认灰红错误屏）
  ErrorWidget.builder = (details) {
    debugPrint('[GlobalError] Widget build error: ${details.exception}');
    return _FriendlyErrorPage(exception: details.exception);
  };

  await WordBookDatabase.ensurePlatform();
  await WordBookDatabase.instance.initialize();
  await UserDatabase.instance.initialize();
  await AppPreferences().init();                // 主题读取的前置依赖

  // 初始化移动端音频会话（确保手机发音功能正常）
  await initMobileAudioSession();

  runApp(const WordApp());
}

class WordApp extends StatefulWidget {
  const WordApp({super.key});

  @override
  State<WordApp> createState() => _WordAppState();
}

/// Widget 构建异常时的友好错误页（替代 Flutter 默认灰红错误屏）
class _FriendlyErrorPage extends StatelessWidget {
  final Object exception;
  const _FriendlyErrorPage({required this.exception});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F4EF),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Color(0xFFB0885A)),
              const SizedBox(height: 16),
              const Text(
                '页面出了一点小问题',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3D3630)),
              ),
              const SizedBox(height: 8),
              Text(
                '我们已记录此问题，请尝试返回或重新进入该页面。\n($exception)',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF8A8078)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordAppState extends State<WordApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
        () => context.read<SkinSystem>()
              .updateSystemBrightness(
                  WidgetsBinding.instance.platformDispatcher.platformBrightness);
  }

  @override
  void didChangePlatformBrightness() {
    // 双保险（部分平台只走这里）
    context.read<SkinSystem>().updateSystemBrightness(
        WidgetsBinding.instance.platformDispatcher.platformBrightness);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LearningState()),
        ChangeNotifierProvider(create: (_) => SkinSystem()),
        ChangeNotifierProvider(create: (_) => WallpaperState()),
      ],
      child: Consumer<SkinSystem>(
        builder: (context, skin, _) {
          return MaterialApp(
            title: 'Monster Word',
            debugShowCheckedModeBanner: false,
            // 注释：不引入 darkTheme+ThemeMode 三件套——三皮肤的暗色是自定义 vars 全量配色，
            // 不是标准 Material darkTheme 能表达的；继续走单一 theme: + Consumer 整体重建。
            // effectiveUiBrightness 正确驱动 ColorScheme。
            theme: ThemeData(
              brightness: skin.effectiveUiBrightness,
              fontFamily: skin.effectiveFontFamily, // 用户字体选择（null=默认 Inter）
              // 灵动转场：Android 缩放淡入 / iOS 滑动(可手势返回) / 桌面向上展开
              pageTransitionsTheme: PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: ZoomPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
                },
              ),
              scaffoldBackgroundColor: skin.colors.pageBg,
              colorScheme: ColorScheme.fromSeed(
                seedColor: skin.colors.accent,
                brightness: skin.effectiveUiBrightness,
              ),
              useMaterial3: true,
            ),
            builder: (context, child) {
              ScreenUtils.init(context);
              return child!;
            },
            home: SkinProvider(
              skin: skin,
              child: AdaptiveScale(
                child: MainShell(
                  tabs: [
                    TabDef(
                      id: 'learn',
                      label: '学习',
                      icon: Icons.auto_stories_outlined,
                      builder: (_) => const HomeScreen(),
                    ),
                    TabDef(
                      id: 'course',
                      label: '课程',
                      icon: Icons.school_outlined,
                      builder: (_) => const LibSelectPage(),
                    ),
                    TabDef(
                      id: 'settings',
                      label: '设置',
                      icon: Icons.settings_outlined,
                      builder: (_) => const ProfileScreen(),
                    ),
                  ],
                ),
              ),
            ),
            onGenerateRoute: (settings) {
              final page = _buildPage(settings);
              if (page == null) return null;
              return _buildPageRoute(settings.name, page);
            },
          );
        },
      ),
    );
  }

  /// 根据路由名称构建页面
  static Widget? _buildPage(RouteSettings settings) {
    final name = settings.name;
    final args = settings.arguments;
    switch (name) {
      case '/learn': return const LearnPage();
      case '/lib_select': return const LibSelectPage();
      case '/book_words':
        // 词书内容页：从路由参数取词书信息（选择词书后展开内容）
        final args = settings.arguments;
        final map = args is Map<String, dynamic> ? args : const <String, dynamic>{};
        return BookWordsPage(
          bookId: (map['bookId'] as num?)?.toInt() ?? 0,
          bookName: (map['bookName'] as String?) ?? '词书',
        );
      case '/review': return const ReviewPage();
      case '/review_session': return const ReviewSession();
      case '/learn_session': return const LearnSession();
      case '/my_space': return const MySpacePage();
      case '/dashboard': return const DashboardPage();
      case '/settings': return const SettingsPage();
      case '/scare_coin_history': return const ScareCoinHistoryPage();
      case '/search': return const SearchPage();
      case '/splash': return const SplashPage();
      case '/login': return const LoginPage();
      case '/my_words': return const MyWordsPage();
      case '/new_words': return const NewWordsPage();
      case '/mastered_words': return const MasteredWordsPage();
      case '/not_learned_words': return const NotLearnedWordsPage();
      case '/reviewing_words': return const ReviewingWordsPage();
      case '/sentence_detail':
        final a = args as Map<String, dynamic>?;
        return SentenceDetailPage(
          word: a?['word'] ?? '', sentence: a?['sentence'] ?? '',
          translation: a?['translation'], source: a?['source'],
        );
      case '/my_fav': return const MyFavPage();
      case '/my_fav_sentence': return const MyFavSentencePage();
      case '/messages': return const MessagePage();
      case '/foot_mark': return const FootMarkPage();
      case '/my_equip': return const MyEquipPage();
      case '/help': return const HelpPage();
      case '/net_diagnosis': return const NetDiagnosisPage();
      case '/user_info_manage': return const UserInfoManagePage();
      case '/theme_select': return const UIThemeSelectPage();
      case '/personal_stereo': return const PersonalStereoPage();
      case '/play_order': return const PlayOrderPage();
      case '/word_listen': return const ListWordListenPage();
      case '/listen_mode_select': return const ExtensiveModelSelectPage();
      case '/sentence_quiz': return const SentenceQuizPage();
      case '/appearance': return const AppearancePage();
      case '/more_settings': return const MoreSettingsPage();
      case '/word_machine': return const WordMachinePage();
      case '/my_content': return const MyContentPage();
      case '/immersive_swipe': return const ImmersiveSwipePage();
      case '/spell_check':
        final a = args as Map<String, dynamic>?;
        return SpellCheckPage(word: a?['word'] ?? '', phonetic: a?['phonetic']);
      case '/spell_session': return const SpellSessionPage();
      case '/linked_me':
        final a = args as Map<String, dynamic>?;
        return LinkedMeMiddlePage(word: a?['word'] ?? '', association: a?['association']);
      case '/word_detail': return const WordDetailPage();
      default: return null;
    }
  }

  /// 根据路由名称选择转场动画
  static Route<dynamic> _buildPageRoute(String? name, Widget page) {
    switch (name) {
      // 上滑进入：设置/个人中心/仪表盘/外观
      case '/settings':
      case '/my_space':
      case '/dashboard':
      case '/appearance':
      case '/more_settings':
      case '/word_machine':
      case '/theme_select':
      case '/user_info_manage':
      case '/help':
      case '/net_diagnosis':
        return SlideUpRoute(page: page) as Route<dynamic>;

      // 渐变进入：学习会话/复习会话
      case '/learn_session':
      case '/review_session':
      case '/learn':
      case '/review':
        return FadeRoute(page: page) as Route<dynamic>;

      // 缩放进入：搜索/弹窗类
      case '/search':
        return ScaleRoute(page: page) as Route<dynamic>;

      // 默认水平滑动（标准 Android 转场）
      default:
        return MaterialPageRoute(builder: (_) => page);
    }
  }
}
