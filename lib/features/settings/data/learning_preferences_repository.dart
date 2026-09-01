import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/settings/application/settings_reader.dart';
import 'package:word_app/features/settings/application/settings_writer.dart';
import 'package:word_app/features/settings/domain/learning_preferences.dart';

/// 学习偏好的 SharedPreferences 持久化边界。
///
/// 原全局设置状态已使用的四个键保持不变。原先仅留在设置页面内存中的选项采用
/// 独立、语义化键名，首次读取时返回页面过去的默认值。
class LearningPreferencesRepository implements SettingsReader, SettingsWriter {
  static const dailyNewWordsKey = 'daily_new_words_v1'; // 与 AppPreferences.dailyNewWordsKey 同 key
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
  static const mnemonicOrderKey = 'mnemonic_order_v1';
  static const showSimilarWordsKey = 'show_similar_words_v1';
  static const showRootsKey = 'show_roots_v1';

  @override
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
      mnemonicOrder: prefs.getString(mnemonicOrderKey) ?? defaults.mnemonicOrder,
      showSimilarWords: prefs.getBool(showSimilarWordsKey) ?? defaults.showSimilarWords,
      showRoots: prefs.getBool(showRootsKey) ?? defaults.showRoots,
    );
  }

  @override
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
      prefs.setString(mnemonicOrderKey, preferences.mnemonicOrder),
      prefs.setBool(showSimilarWordsKey, preferences.showSimilarWords),
      prefs.setBool(showRootsKey, preferences.showRoots),
    ]);
  }
}
