/// 路由名称常量。
///
/// 名称是外部深链、页面导航与转场策略之间的稳定合同；功能域路由只能引用，不能
/// 在各自模块中复制字符串。
class RouteNames {
  static const String home = '/home';
  static const String learn = '/learn';
  static const String libSelect = '/lib_select';
  static const String bookWords = '/book-words';
  static const String review = '/review';

  /// 兼容历史深链；会被重定向到唯一的正式复习流程 [review]。
  @Deprecated('Use RouteNames.review. The legacy route redirects to the formal review flow.')
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
  static const String designLanguage = '/design_language';
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
  static const String classCheckin = '/class_checkin';
  static const String classActivity = '/class_activity';
  static const String linkedMe = '/linked_me';
  static const String wordDetail = '/word_detail';
  static const String dictionary = '/dictionary';
  static const String dictionaryByName = '/dictionary/byName';
  static const String listeningPlayer = '/listening_player';
  static const String dictationSession = '/dictation_session';
  static const String quickSpell = '/quick_spell';
  static const String wordExport = '/word_export';
}
