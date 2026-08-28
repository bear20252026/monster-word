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
