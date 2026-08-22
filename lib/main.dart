// 由账号4生成
// 不背单词 App 入口：接入新设计系统（SkinProvider + MainShell + 三主题）
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/wordbook_database.dart';
import 'pages/dashboard_page.dart';
import 'pages/learn_page.dart';
import 'pages/lib_select_page.dart';
import 'pages/my_space_page.dart';
import 'pages/review_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';
import 'screens/home_screen.dart';
import 'screens/learn_session.dart';
import 'screens/profile_screen.dart';
import 'screens/review_session.dart';
import 'shell/main_shell.dart';
import 'state/learning_state.dart';
import 'theme/skin_system.dart';
import 'widgets/adaptive_scale.dart';
import 'widgets/glass_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WordBookDatabase.ensurePlatform();
  await WordBookDatabase.instance.initialize();
  runApp(const WordApp());
}

class WordApp extends StatelessWidget {
  const WordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LearningState()),
        ChangeNotifierProvider(create: (_) => SkinSystem()),
      ],
      child: Consumer<SkinSystem>(
        builder: (context, skin, _) {
          return MaterialApp(
            title: '不背单词',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: skin.currentTheme.statusBarBrightness,
              scaffoldBackgroundColor: skin.colors.pageBg,
              colorScheme: ColorScheme.fromSeed(
                seedColor: skin.colors.accent,
                brightness: skin.currentTheme.statusBarBrightness,
              ),
              useMaterial3: true,
            ),
            home: SkinProvider(
              skin: skin,
              child: AdaptiveScale(
                child: MainShell(
                  tabs: [
                    TabDef(
                      id: 'home',
                      label: '首页',
                      icon: Icons.home_outlined,
                      builder: (_) => const HomeScreen(),
                    ),
                    TabDef(
                      id: 'lexicon',
                      label: '词库',
                      icon: Icons.menu_book_outlined,
                      builder: (_) => const LibSelectPage(),
                    ),
                    TabDef(
                      id: 'mine',
                      label: '我的',
                      icon: Icons.person_outline,
                      builder: (_) => const ProfileScreen(),
                    ),
                  ],
                ),
              ),
            ),
            routes: {
              LearnPage.routeName: (context) => const LearnPage(),
              LibSelectPage.routeName: (context) => const LibSelectPage(),
              ReviewPage.routeName: (context) => const ReviewPage(),
              ReviewSession.routeName: (context) => const ReviewSession(),
              LearnSession.routeName: (context) => const LearnSession(),
              MySpacePage.routeName: (context) => const MySpacePage(),
              DashboardPage.routeName: (context) => const DashboardPage(),
              SettingsPage.routeName: (context) => const SettingsPage(),
              SearchPage.routeName: (context) => const SearchPage(),
            },
          );
        },
      ),
    );
  }
}
