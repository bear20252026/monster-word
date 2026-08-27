import 'package:shared_preferences/shared_preferences.dart';

/// 设置页所展示学习偏好的不可变值对象。
///
/// 该对象只表达用户显式可配置的学习偏好；主题、壁纸、账户和学习进度继续由各自
/// 功能域拥有，避免重新形成全局偏好聚合状态。
class LearningPreferences {
  const LearningPreferences({
    required this.dailyNewWords,
    required this.autoPlayAudio,
    required this.showPhonetic,
    required this.darkMode,
    required this.wechatReminder,
    required this.systemReminder,
    required this.pronunciationType,
    required this.autoPlayExampleAudio,
    required this.spellRightSwipe,
    required this.spellReviewTip,
    required this.learnPace,
    required this.reviewMode,
    required this.reviewPace,
    required this.audioMeaningQuestion,
    required this.splitMnemonic,
    required this.showConfusableMeanings,
  });

  const LearningPreferences.defaults()
    : dailyNewWords = 10,
      autoPlayAudio = true,
      showPhonetic = true,
      darkMode = false,
      wechatReminder = false,
      systemReminder = true,
      pronunciationType = '美式',
      autoPlayExampleAudio = false,
      spellRightSwipe = true,
      spellReviewTip = true,
      learnPace = 10,
      reviewMode = '新模式',
      reviewPace = 10,
      audioMeaningQuestion = true,
      splitMnemonic = true,
      showConfusableMeanings = true;

  final int dailyNewWords;
  final bool autoPlayAudio;
  final bool showPhonetic;
  final bool darkMode;
  final bool wechatReminder;
  final bool systemReminder;
  final String pronunciationType;
  final bool autoPlayExampleAudio;
  final bool spellRightSwipe;
  final bool spellReviewTip;
  final int learnPace;
  final String reviewMode;
  final int reviewPace;
  final bool audioMeaningQuestion;
  final bool splitMnemonic;
  final bool showConfusableMeanings;

  LearningPreferences copyWith({
    int? dailyNewWords,
    bool? autoPlayAudio,
    bool? showPhonetic,
    bool? darkMode,
    bool? wechatReminder,
    bool? systemReminder,
    String? pronunciationType,
    bool? autoPlayExampleAudio,
    bool? spellRightSwipe,
    bool? spellReviewTip,
    int? learnPace,
    String? reviewMode,
    int? reviewPace,
    bool? audioMeaningQuestion,
    bool? splitMnemonic,
    bool? showConfusableMeanings,
  }) {
    return LearningPreferences(
      dailyNewWords: dailyNewWords ?? this.dailyNewWords,
      autoPlayAudio: autoPlayAudio ?? this.autoPlayAudio,
      showPhonetic: showPhonetic ?? this.showPhonetic,
      darkMode: darkMode ?? this.darkMode,
      wechatReminder: wechatReminder ?? this.wechatReminder,
      systemReminder: systemReminder ?? this.systemReminder,
      pronunciationType: pronunciationType ?? this.pronunciationType,
      autoPlayExampleAudio: autoPlayExampleAudio ?? this.autoPlayExampleAudio,
      spellRightSwipe: spellRightSwipe ?? this.spellRightSwipe,
      spellReviewTip: spellReviewTip ?? this.spellReviewTip,
      learnPace: learnPace ?? this.learnPace,
      reviewMode: reviewMode ?? this.reviewMode,
      reviewPace: reviewPace ?? this.reviewPace,
      audioMeaningQuestion: audioMeaningQuestion ?? this.audioMeaningQuestion,
      splitMnemonic: splitMnemonic ?? this.splitMnemonic,
      showConfusableMeanings: showConfusableMeanings ?? this.showConfusableMeanings,
    );
  }
}

/// 学习偏好的 SharedPreferences 持久化边界。
///
/// 原全局设置状态已使用的四个键保持不变。原先仅留在设置页面内存中的选项采用
/// 独立、语义化键名，首次读取时返回页面过去的默认值。
class LearningPreferencesRepository {
  static const dailyNewWordsKey = 'daily_new_words_v1';
  static const autoPlayAudioKey = 'auto_play_audio_v1';
  static const showPhoneticKey = 'show_phonetic_v1';
  static const darkModeKey = 'dark_mode_v1';
  static const wechatReminderKey = 'wechat_reminder_v1';
  static const systemReminderKey = 'system_reminder_v1';
  static const pronunciationTypeKey = 'pronunciation_type_v1';
  static const autoPlayExampleAudioKey = 'auto_play_example_audio_v1';
  static const spellRightSwipeKey = 'spell_right_swipe_v1';
  static const spellReviewTipKey = 'spell_review_tip_v1';
  static const learnPaceKey = 'learn_pace_v1';
  static const reviewModeKey = 'review_mode_v1';
  static const reviewPaceKey = 'review_pace_v1';
  static const audioMeaningQuestionKey = 'audio_meaning_question_v1';
  static const splitMnemonicKey = 'split_mnemonic_v1';
  static const showConfusableMeaningsKey = 'show_confusable_meanings_v1';

  Future<LearningPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    const defaults = LearningPreferences.defaults();
    return LearningPreferences(
      dailyNewWords: prefs.getInt(dailyNewWordsKey) ?? defaults.dailyNewWords,
      autoPlayAudio: prefs.getBool(autoPlayAudioKey) ?? defaults.autoPlayAudio,
      showPhonetic: prefs.getBool(showPhoneticKey) ?? defaults.showPhonetic,
      darkMode: prefs.getBool(darkModeKey) ?? defaults.darkMode,
      wechatReminder: prefs.getBool(wechatReminderKey) ?? defaults.wechatReminder,
      systemReminder: prefs.getBool(systemReminderKey) ?? defaults.systemReminder,
      pronunciationType: prefs.getString(pronunciationTypeKey) ?? defaults.pronunciationType,
      autoPlayExampleAudio: prefs.getBool(autoPlayExampleAudioKey) ?? defaults.autoPlayExampleAudio,
      spellRightSwipe: prefs.getBool(spellRightSwipeKey) ?? defaults.spellRightSwipe,
      spellReviewTip: prefs.getBool(spellReviewTipKey) ?? defaults.spellReviewTip,
      learnPace: prefs.getInt(learnPaceKey) ?? defaults.learnPace,
      reviewMode: prefs.getString(reviewModeKey) ?? defaults.reviewMode,
      reviewPace: prefs.getInt(reviewPaceKey) ?? defaults.reviewPace,
      audioMeaningQuestion: prefs.getBool(audioMeaningQuestionKey) ?? defaults.audioMeaningQuestion,
      splitMnemonic: prefs.getBool(splitMnemonicKey) ?? defaults.splitMnemonic,
      showConfusableMeanings: prefs.getBool(showConfusableMeaningsKey) ?? defaults.showConfusableMeanings,
    );
  }

  Future<void> save(LearningPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt(dailyNewWordsKey, preferences.dailyNewWords),
      prefs.setBool(autoPlayAudioKey, preferences.autoPlayAudio),
      prefs.setBool(showPhoneticKey, preferences.showPhonetic),
      prefs.setBool(darkModeKey, preferences.darkMode),
      prefs.setBool(wechatReminderKey, preferences.wechatReminder),
      prefs.setBool(systemReminderKey, preferences.systemReminder),
      prefs.setString(pronunciationTypeKey, preferences.pronunciationType),
      prefs.setBool(autoPlayExampleAudioKey, preferences.autoPlayExampleAudio),
      prefs.setBool(spellRightSwipeKey, preferences.spellRightSwipe),
      prefs.setBool(spellReviewTipKey, preferences.spellReviewTip),
      prefs.setInt(learnPaceKey, preferences.learnPace),
      prefs.setString(reviewModeKey, preferences.reviewMode),
      prefs.setInt(reviewPaceKey, preferences.reviewPace),
      prefs.setBool(audioMeaningQuestionKey, preferences.audioMeaningQuestion),
      prefs.setBool(splitMnemonicKey, preferences.splitMnemonic),
      prefs.setBool(showConfusableMeaningsKey, preferences.showConfusableMeanings),
    ]);
  }
}
