import 'package:flutter/foundation.dart';

import 'package:word_app/features/settings/application/settings_reader.dart';
import 'package:word_app/features/settings/application/settings_writer.dart';
import 'package:word_app/features/settings/domain/learning_preferences.dart';

/// 设置页的可订阅学习偏好状态。
///
/// 所有值通过 [SettingsReader] / [SettingsWriter] 端口读写。页面只发送明确的偏好命令，
/// 不再保存会在离开页面后丢失的本地设置副本。
class LearningPreferencesState extends ChangeNotifier {
  LearningPreferencesState({
    required this._reader,
    required this._writer,
  });

  final SettingsReader _reader;
  final SettingsWriter _writer;

  LearningPreferences _preferences = const LearningPreferences.defaults();
  bool _isLoading = true;
  Object? _loadError;

  LearningPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;
  Object? get loadError => _loadError;

  int get dailyNewWords => _preferences.dailyNewWords;
  bool get autoPlayAudio => _preferences.autoPlayAudio;
  bool get showPhonetic => _preferences.showPhonetic;
  bool get darkMode => _preferences.darkMode;
  bool get wechatReminder => _preferences.wechatReminder;
  bool get systemReminder => _preferences.systemReminder;
  String get pronunciationType => _preferences.pronunciationType;
  bool get autoPlayExampleAudio => _preferences.autoPlayExampleAudio;
  bool get spellRightSwipe => _preferences.spellRightSwipe;
  bool get spellReviewTip => _preferences.spellReviewTip;
  int get learnPace => _preferences.learnPace;
  String get reviewMode => _preferences.reviewMode;
  int get reviewPace => _preferences.reviewPace;
  bool get audioMeaningQuestion => _preferences.audioMeaningQuestion;
  bool get splitMnemonic => _preferences.splitMnemonic;
  bool get showConfusableMeanings => _preferences.showConfusableMeanings;

  Future<void> initialize() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _preferences = await _reader.load();
    } catch (error) {
      _loadError = error;
      debugPrint('Learning preferences loading error: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setDailyNewWords(int value) => _update(_preferences.copyWith(dailyNewWords: value));
  Future<void> setAutoPlayAudio(bool value) => _update(_preferences.copyWith(autoPlayAudio: value));
  Future<void> setShowPhonetic(bool value) => _update(_preferences.copyWith(showPhonetic: value));
  Future<void> setDarkMode(bool value) => _update(_preferences.copyWith(darkMode: value));
  Future<void> setWechatReminder(bool value) => _update(_preferences.copyWith(wechatReminder: value));
  Future<void> setSystemReminder(bool value) => _update(_preferences.copyWith(systemReminder: value));
  Future<void> setPronunciationType(String value) => _update(_preferences.copyWith(pronunciationType: value));
  Future<void> setAutoPlayExampleAudio(bool value) => _update(_preferences.copyWith(autoPlayExampleAudio: value));
  Future<void> setSpellRightSwipe(bool value) => _update(_preferences.copyWith(spellRightSwipe: value));
  Future<void> setSpellReviewTip(bool value) => _update(_preferences.copyWith(spellReviewTip: value));
  Future<void> setLearnPace(int value) => _update(_preferences.copyWith(learnPace: value));
  Future<void> setReviewMode(String value) => _update(_preferences.copyWith(reviewMode: value));
  Future<void> setReviewPace(int value) => _update(_preferences.copyWith(reviewPace: value));
  Future<void> setAudioMeaningQuestion(bool value) => _update(_preferences.copyWith(audioMeaningQuestion: value));
  Future<void> setSplitMnemonic(bool value) => _update(_preferences.copyWith(splitMnemonic: value));
  Future<void> setShowConfusableMeanings(bool value) => _update(_preferences.copyWith(showConfusableMeanings: value));

  Future<void> _update(LearningPreferences next) async {
    if (identical(next, _preferences)) return;
    _preferences = next;
    notifyListeners();
    try {
      await _writer.save(next);
    } catch (error) {
      debugPrint('Learning preferences saving error: $error');
    }
  }
}
