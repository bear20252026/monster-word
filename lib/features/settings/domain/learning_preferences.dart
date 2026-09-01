import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/settings/domain/reminder_time.dart';

/// 设置页所展示学习偏好的不可变值对象。
///
/// 该对象只表达用户显式可配置的学习偏好；主题、壁纸、账户和学习进度继续由各自
/// 功能域拥有，避免重新形成全局偏好聚合状态。
class LearningPreferences {
  /// 助记段落默认顺序（单一事实来源：AppPreferences.defaultMnemonicOrder，
  /// 逗号分隔存储；消费方：设置页助记顺序弹窗 + 单词详情页助记段落排序）。
  static const String defaultMnemonicOrder = AppPreferences.defaultMnemonicOrder;

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
    required this.mnemonicOrder,
    required this.showSimilarWords,
    required this.showRoots,
    required this.reminderTime,
  });

  const LearningPreferences.defaults()
    : dailyNewWords = 10,
      autoPlayAudio = true,
      showPhonetic = true,
      darkMode = false,
      wechatReminder = false,
      // 系统提醒默认关闭：真实现下未开启即不调度，用户主动开启才申请通知权限。
      systemReminder = false,
      pronunciationType = '美式',
      autoPlayExampleAudio = false,
      spellRightSwipe = true,
      spellReviewTip = true,
      learnPace = 10,
      reviewMode = '新模式',
      reviewPace = 10,
      audioMeaningQuestion = true,
      splitMnemonic = true,
      showConfusableMeanings = true,
      mnemonicOrder = defaultMnemonicOrder,
      showSimilarWords = true,
      showRoots = true,
      reminderTime = defaultReminderTime;

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

  /// 助记段落顺序（逗号分隔的段落名，如 '派生词,词组搭配,特殊变形,词根词缀'）。
  final String mnemonicOrder;

  /// 单词详情页是否显示形近词（特殊变形）。
  final bool showSimilarWords;

  /// 单词详情页是否显示词根词缀。
  final bool showRoots;

  /// 每日学习提醒时间（24 小时制 'HH:mm'，系统提醒开关的真实现消费方）。
  final String reminderTime;

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
    String? mnemonicOrder,
    bool? showSimilarWords,
    bool? showRoots,
    String? reminderTime,
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
      mnemonicOrder: mnemonicOrder ?? this.mnemonicOrder,
      showSimilarWords: showSimilarWords ?? this.showSimilarWords,
      showRoots: showRoots ?? this.showRoots,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}
