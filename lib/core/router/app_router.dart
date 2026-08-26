// 由 Claude 团队生成 | Monster Word App
// AppRouter — 路由配置（从 main.dart 抽取）

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/word.dart';
import '../pages/account_info_page.dart';
import '../pages/appearance_page.dart';
import '../pages/book_words_page.dart';
import '../pages/check_in_history_page.dart';
import '../pages/courses_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/dictation_session_page.dart';
import '../pages/extensive_model_select_page.dart';
import '../pages/feedback_page.dart';
import '../pages/foot_mark_page.dart';
import '../pages/help_page.dart';
import '../pages/immersive_swipe_page.dart';
import '../pages/learn_page.dart';
import '../pages/linked_me_middle_page.dart';
import '../pages/lib_select_page.dart';
import '../pages/list_word_listen_page.dart';
import '../pages/listening_player_page.dart';
import '../pages/login_page.dart';
import '../pages/mastered_words_page.dart';
import '../pages/message_page.dart';
import '../pages/more_settings_page.dart';
import '../pages/my_content_page.dart';
import '../pages/my_equip_page.dart';
import '../pages/my_fav_page.dart';
import '../pages/my_fav_sentence_page.dart';
import '../pages/my_space_page.dart';
import '../pages/my_words_page.dart';
import '../pages/net_diagnosis_page.dart';
import '../pages/new_words_page.dart';
import '../pages/not_learned_words_page.dart';
import '../pages/personal_stereo_page.dart';
import '../pages/play_order_page.dart';
import '../pages/quick_spell_page.dart';
import '../pages/redemption_center_page.dart';
import '../pages/review_page.dart';
import '../pages/reviewing_words_page.dart';
import '../pages/scare_coin_history_page.dart';
import '../pages/search_page.dart';
import '../pages/sentence_detail_page.dart';
import '../pages/sentence_quiz_page.dart';
import '../pages/settings_page.dart';
import '../pages/spell_check_page.dart';
import '../pages/spell_session_page.dart';
import '../pages/splash_page.dart';
import '../pages/ui_theme_select_page.dart';
import '../pages/user_info_manage_page.dart';
import '../pages/word_detail_page.dart';
import '../pages/word_export_page.dart';
import '../pages/word_machine_page.dart';
import '../screens/learn_session.dart';
import '../screens/profile_screen.dart';
import '../screens/review_session.dart';
import '../widgets/transition_widgets.dart';

/// 路由名称常量
class RouteNames {
  static const String learn = '/learn';
  static const String libSelect = '/lib_select';
  static const String bookWords = '/book_words';
  static const String review = '/review';
  static const String reviewSession = '/review_session';
  static const String learnSession = '/learn_session';
  static const String course = '/course';
  static const String mySpace = '/my_space';
  static const String dashboard = '/dashboard';
  static const String settings = '/settings';
  static const String scareCoinHistory = '/scare_coin_history';
  static const String search = '/search';
  static const String splash = '/splash';
  static const String login = '/login';
  static const String myWords = '/my_words';
  static const String newWords = '/new_words';
  static const String masteredWords = '/mastered_words';
  static const String notLearnedWords = '/not_learned_words';
  static const String reviewingWords = '/reviewing_words';
  static const String sentenceDetail = '/sentence_detail';
  static const String myFav = '/my_fav';
  static const String myFavSentence = '/my_fav_sentence';
  static const String messages = '/messages';
  static const String footMark = '/foot_mark';
  static const String myEquip = '/my_equip';
  static const String help = '/help';
  static const String netDiagnosis = '/net_diagnosis';
  static const String userInfoManage = '/user_info_manage';
  static const String themeSelect = '/theme_select';
  static const String personalStereo = '/personal_stereo';
  static const String playOrder = '/play_order';
  static const String wordListen = '/word_listen';
  static const String listenModeSelect = '/listen_mode_select';
  static const String sentenceQuiz = '/sentence_quiz';
  static const String appearance = '/appearance';
  static const String moreSettings = '/more_settings';
  static const String accountInfo = '/account_info';
  static const String feedback = '/feedback';
  static const String redemption = '/redemption';
  static const String wordMachine = '/word_machine';
  static const String myContent = '/my_content';
  static const String immersiveSwipe = '/immersive_swipe';
  static const String spellCheck = '/spell_check';
  static const String spellSession = '/spell_session';
  static const String checkInHistory = '/check_in_history';
  static const String linkedMe = '/linked_me';
  static const String wordDetail = '/word_detail';
  static const String listeningPlayer = '/listening_player';
  static const String dictationSession = '/dictation_session';
  static const String quickSpell = '/quick_spell';
  static const String wordExport = '/word_export';
}

/// 路由配置类
/// 
/// 集中管理所有路由定义，包括：
/// - 路由名称常量
/// - 页面构建逻辑
/// - 转场动画选择
class AppRouter {
  /// 根据路由设置生成页面
  static Widget? buildPage(RouteSettings settings) {
    final name = settings.name;
    final args = settings.arguments;

    switch (name) {
      case RouteNames.learn:
        return const LearnPage();
      case RouteNames.libSelect:
        return const LibSelectPage();
      case RouteNames.bookWords:
        return _buildBookWordsPage(args);
      case RouteNames.review:
        return const ReviewPage();
      case RouteNames.reviewSession:
        return const ReviewSession();
      case RouteNames.learnSession:
        return const LearnSession();
      case RouteNames.course:
        return const CoursesPage();
      case RouteNames.mySpace:
        return const MySpacePage();
      case RouteNames.dashboard:
        return const DashboardPage();
      case RouteNames.settings:
        return const SettingsPage();
      case RouteNames.scareCoinHistory:
        return const ScareCoinHistoryPage();
      case RouteNames.search:
        return const SearchPage();
      case RouteNames.splash:
        return const SplashPage();
      case RouteNames.login:
        return const LoginPage();
      case RouteNames.myWords:
        return const MyWordsPage();
      case RouteNames.newWords:
        return const NewWordsPage();
      case RouteNames.masteredWords:
        return const MasteredWordsPage();
      case RouteNames.notLearnedWords:
        return const NotLearnedWordsPage();
      case RouteNames.reviewingWords:
        return const ReviewingWordsPage();
      case RouteNames.sentenceDetail:
        return _buildSentenceDetailPage(args);
      case RouteNames.myFav:
        return const MyFavPage();
      case RouteNames.myFavSentence:
        return const MyFavSentencePage();
      case RouteNames.messages:
        return const MessagePage();
      case RouteNames.footMark:
        return const FootMarkPage();
      case RouteNames.myEquip:
        return const MyEquipPage();
      case RouteNames.help:
        return const HelpPage();
      case RouteNames.netDiagnosis:
        return const NetDiagnosisPage();
      case RouteNames.userInfoManage:
        return const UserInfoManagePage();
      case RouteNames.themeSelect:
        return const UIThemeSelectPage();
      case RouteNames.personalStereo:
        return const PersonalStereoPage();
      case RouteNames.playOrder:
        return const PlayOrderPage();
      case RouteNames.wordListen:
        return const ListWordListenPage();
      case RouteNames.listenModeSelect:
        return _buildListenModeSelectPage(args);
      case RouteNames.sentenceQuiz:
        return const SentenceQuizPage();
      case RouteNames.appearance:
        return const AppearancePage();
      case RouteNames.moreSettings:
        return const MoreSettingsPage();
      case RouteNames.accountInfo:
        return const AccountInfoPage();
      case RouteNames.feedback:
        return const FeedbackPage();
      case RouteNames.redemption:
        return const RedemptionCenterPage();
      case RouteNames.wordMachine:
        return const WordMachinePage();
      case RouteNames.myContent:
        return const MyContentPage();
      case RouteNames.immersiveSwipe:
        return const ImmersiveSwipePage();
      case RouteNames.spellCheck:
        return _buildSpellCheckPage(args);
      case RouteNames.spellSession:
        return const SpellSessionPage();
      case RouteNames.checkInHistory:
        return const CheckInHistoryPage();
      case RouteNames.linkedMe:
        return _buildLinkedMePage(args);
      case RouteNames.wordDetail:
        return const WordDetailPage();
      case RouteNames.listeningPlayer:
        return _buildListeningPlayerPage(args);
      case RouteNames.dictationSession:
        return _buildDictationSessionPage(args);
      case RouteNames.quickSpell:
        return _buildQuickSpellPage(args);
      case RouteNames.wordExport:
        return _buildWordExportPage(args);
      default:
        return _friendlyErrorPage(name ?? 'unknown', '页面不存在');
    }
  }

  /// 根据路由名称选择转场动画
  static Route<dynamic> buildPageRoute(String? name, Widget page) {
    switch (name) {
      // 上滑进入：设置/个人中心/仪表盘/外观
      case RouteNames.settings:
      case RouteNames.mySpace:
      case RouteNames.dashboard:
      case RouteNames.appearance:
      case RouteNames.moreSettings:
      case RouteNames.wordMachine:
      case RouteNames.themeSelect:
      case RouteNames.userInfoManage:
      case RouteNames.help:
      case RouteNames.netDiagnosis:
      case RouteNames.checkInHistory:
        return SlideUpRoute(page: page) as Route<dynamic>;

      // 渐变进入：学习会话/复习会话
      case RouteNames.learnSession:
      case RouteNames.reviewSession:
      case RouteNames.learn:
      case RouteNames.review:
        return FadeRoute(page: page) as Route<dynamic>;

      // 缩放进入：搜索/弹窗类
      case RouteNames.search:
        return ScaleRoute(page: page) as Route<dynamic>;

      // 默认水平滑动（标准 Android 转场）
      default:
        return MaterialPageRoute(builder: (_) => page);
    }
  }

  // ========== 私有辅助方法 ==========

  static Widget _buildBookWordsPage(Object? args) {
    if (args is Book) {
      return BookWordsPage(bookId: args.id, bookName: args.name);
    }
    final map = args is Map<String, dynamic> ? args : const <String, dynamic>{};
    return BookWordsPage(
      bookId: (map['bookId'] as num?)?.toInt() ?? 0,
      bookName: (map['bookName'] as String?) ?? '词书',
    );
  }

  static Widget _buildSentenceDetailPage(Object? args) {
    final a = args is Map<String, dynamic> ? args : null;
    return SentenceDetailPage(
      word: a?['word'] as String? ?? '',
      sentence: a?['sentence'] as String? ?? '',
      translation: a?['translation'] as String?,
      source: a?['source'] as String?,
    );
  }

  static Widget _buildListenModeSelectPage(Object? args) {
    final a = args is Map<String, dynamic> ? args : null;
    if (a == null) {
      return const _RouteErrorPage(routeName: 'listen_mode_select', message: '缺少必要参数');
    }
    final bookId = (a['bookId'] as num?)?.toInt() ?? 0;
    return ExtensiveModelSelectPage(
      bookId: bookId,
      bookName: a['bookName'] as String? ?? '',
    );
  }

  static Widget _buildSpellCheckPage(Object? args) {
    final a = args is Map<String, dynamic> ? args : null;
    return SpellCheckPage(
      word: a?['word'] as String? ?? '',
      phonetic: a?['phonetic'] as String?,
    );
  }

  static Widget _buildLinkedMePage(Object? args) {
    final a = args is Map<String, dynamic> ? args : null;
    return LinkedMeMiddlePage(
      word: a?['word'] as String? ?? '',
      association: a?['association'] as String?,
    );
  }

  static Widget _buildListeningPlayerPage(Object? args) {
    final a = args is Map<String, dynamic> ? args : null;
    if (a == null) {
      return const _RouteErrorPage(routeName: 'listening_player', message: '缺少必要参数');
    }
    final words = (a['words'] as List?)?.map((e) => e as Word).toList() ?? [];
    final modeIdx = (a['mode'] as num?)?.toInt() ?? 0;
    final mode = modeIdx >= 0 && modeIdx < ListeningMode.values.length
        ? ListeningMode.values[modeIdx]
        : ListeningMode.wordOnly;
    return ListeningPlayerPage(
      words: words,
      mode: mode,
      bookName: a['bookName'] as String? ?? '',
    );
  }

  static Widget _buildDictationSessionPage(Object? args) {
    final a = args is Map<String, dynamic> ? args : null;
    if (a == null) {
      return const _RouteErrorPage(routeName: 'dictation_session', message: '缺少必要参数');
    }
    final words = (a['words'] as List?)?.map((e) => e as Word).toList() ?? [];
    return DictationSessionPage(
      words: words,
      bookName: a['bookName'] as String? ?? '',
    );
  }

  static Widget _buildQuickSpellPage(Object? args) {
    final a = args is Map<String, dynamic> ? args : null;
    if (a == null) {
      return const _RouteErrorPage(routeName: 'quick_spell', message: '缺少必要参数');
    }
    final words = (a['words'] as List?)?.map((e) => e as Word).toList() ?? [];
    return QuickSpellPage(
      words: words,
      bookName: a['bookName'] as String? ?? '',
    );
  }

  static Widget _buildWordExportPage(Object? args) {
    final a = args is Map<String, dynamic> ? args : null;
    if (a == null) {
      return const _RouteErrorPage(routeName: 'word_export', message: '缺少必要参数');
    }
    final bookId = (a['bookId'] as num?)?.toInt() ?? 0;
    return WordExportPage(
      bookId: bookId,
      bookName: a['bookName'] as String? ?? '',
    );
  }

  /// 路由错误页
  static Widget _friendlyErrorPage(String routeName, String message) {
    return _RouteErrorPage(routeName: routeName, message: message);
  }
}

/// 路由错误页组件
class _RouteErrorPage extends StatelessWidget {
  final String routeName;
  final String message;

  const _RouteErrorPage({
    required this.routeName,
    required this.message,
  });

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
              const Icon(Icons.warning_amber_rounded, size: 56, color: Color(0xFFB0885A)),
              const SizedBox(height: 16),
              Text(
                '无法打开 $routeName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3D3630),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF8A8078)),
              ),
              const SizedBox(height: 24),
              Builder(
                builder: (ctx) => ElevatedButton.icon(
                  onPressed: () {
                    final nav = Navigator.of(ctx);
                    if (nav.canPop()) {
                      nav.pop();
                    } else {
                      nav.popUntil((r) => r.isFirst);
                    }
                  },
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: const Text('返回首页'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006241),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
