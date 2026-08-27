import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/features/settings/data/learning_preferences_repository.dart';
import 'package:word_app/features/settings/presentation/learning_preferences_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('学习偏好状态加载旧 SettingsState 的每日新学和发音键', () async {
    SharedPreferences.setMockInitialValues({
      LearningPreferencesRepository.dailyNewWordsKey: 30,
      LearningPreferencesRepository.autoPlayAudioKey: false,
      LearningPreferencesRepository.showPhoneticKey: false,
      LearningPreferencesRepository.darkModeKey: true,
    });
    final state = LearningPreferencesState(repository: LearningPreferencesRepository());

    await state.initialize();

    expect(state.dailyNewWords, 30);
    expect(state.autoPlayAudio, isFalse);
    expect(state.showPhonetic, isFalse);
    expect(state.darkMode, isTrue);
    expect(state.isLoading, isFalse);
  });

  test('学习偏好状态持久化设置页的节奏、发音和拼写更新', () async {
    final state = LearningPreferencesState(repository: LearningPreferencesRepository());
    await state.initialize();

    await state.setDailyNewWords(20);
    await state.setPronunciationType('英式');
    await state.setAutoPlayExampleAudio(true);
    await state.setLearnPace(15);
    await state.setReviewMode('旧模式');
    await state.setReviewPace(40);
    await state.setSpellRightSwipe(false);
    await state.setAudioMeaningQuestion(false);

    final preferences = await SharedPreferences.getInstance();
    expect(state.dailyNewWords, 20);
    expect(state.pronunciationType, '英式');
    expect(state.autoPlayExampleAudio, isTrue);
    expect(state.learnPace, 15);
    expect(state.reviewMode, '旧模式');
    expect(state.reviewPace, 40);
    expect(state.spellRightSwipe, isFalse);
    expect(state.audioMeaningQuestion, isFalse);
    expect(preferences.getInt(LearningPreferencesRepository.dailyNewWordsKey), 20);
    expect(preferences.getString(LearningPreferencesRepository.pronunciationTypeKey), '英式');
    expect(preferences.getInt(LearningPreferencesRepository.reviewPaceKey), 40);
    expect(preferences.getBool(LearningPreferencesRepository.spellRightSwipeKey), isFalse);
  });

  test('学习偏好状态将提醒与助记开关写入各自的显式事实键', () async {
    final state = LearningPreferencesState(repository: LearningPreferencesRepository());
    await state.initialize();

    await state.setWechatReminder(true);
    await state.setSystemReminder(false);
    await state.setSplitMnemonic(false);
    await state.setShowConfusableMeanings(false);

    final preferences = await SharedPreferences.getInstance();
    expect(state.wechatReminder, isTrue);
    expect(state.systemReminder, isFalse);
    expect(state.splitMnemonic, isFalse);
    expect(state.showConfusableMeanings, isFalse);
    expect(preferences.getBool(LearningPreferencesRepository.wechatReminderKey), isTrue);
    expect(preferences.getBool(LearningPreferencesRepository.systemReminderKey), isFalse);
    expect(preferences.getBool(LearningPreferencesRepository.splitMnemonicKey), isFalse);
    expect(preferences.getBool(LearningPreferencesRepository.showConfusableMeaningsKey), isFalse);
  });
}
