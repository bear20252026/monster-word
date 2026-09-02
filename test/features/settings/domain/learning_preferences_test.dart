import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/settings/domain/learning_preferences.dart';

void main() {
  group('LearningPreferences', () {
    test('defaults 返回所有字段的默认值', () {
      const prefs = LearningPreferences.defaults();

      expect(prefs.dailyNewWords, 10);
      expect(prefs.autoPlayAudio, isTrue);
      expect(prefs.showPhonetic, isTrue);
      expect(prefs.darkMode, isFalse);
      expect(prefs.wechatReminder, isFalse);
      // 真实现下默认关闭：未开启即不调度，用户主动开启才申请通知权限。
      expect(prefs.systemReminder, isFalse);
      expect(prefs.pronunciationType, '美式');
      expect(prefs.autoPlayExampleAudio, isFalse);
      expect(prefs.spellRightSwipe, isTrue);
      expect(prefs.spellReviewTip, isTrue);
      expect(prefs.learnPace, 10);
      expect(prefs.audioMeaningQuestion, isTrue);
      expect(prefs.splitMnemonic, isTrue);
      expect(prefs.showConfusableMeanings, isTrue);
    });

    test('copyWith 保留未修改字段', () {
      const original = LearningPreferences.defaults();
      final modified = original.copyWith(dailyNewWords: 30, darkMode: true);

      expect(modified.dailyNewWords, 30);
      expect(modified.darkMode, isTrue);
      expect(modified.autoPlayAudio, original.autoPlayAudio);
      expect(modified.pronunciationType, original.pronunciationType);
      expect(modified.learnPace, original.learnPace);
    });

    test('copyWith 只修改指定字段', () {
      const original = LearningPreferences.defaults();
      final modified = original.copyWith(learnPace: 20);

      expect(modified.learnPace, 20);
      expect(modified.dailyNewWords, original.dailyNewWords);
      expect(modified.autoPlayAudio, original.autoPlayAudio);
    });

    test('不可变性：copyWith 返回新实例', () {
      const original = LearningPreferences.defaults();
      final modified = original.copyWith(dailyNewWords: 50);

      expect(identical(original, modified), isFalse);
      expect(original.dailyNewWords, 10);
      expect(modified.dailyNewWords, 50);
    });
  });
}
