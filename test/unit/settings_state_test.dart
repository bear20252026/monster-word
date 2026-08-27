import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/state/settings_state.dart';

void main() {
  test('SettingsState 加载既有每日新学词数', () async {
    SharedPreferences.setMockInitialValues({'daily_new_words_v1': 30});
    final state = SettingsState();

    await state.init();

    expect(state.dailyNewWords, 30);
    expect(state.initialized, isTrue);
  });

  test('SettingsState 更新每日新学词数时继续写入既有键', () async {
    SharedPreferences.setMockInitialValues({});
    final state = SettingsState();
    await state.init();

    await state.setDailyNewWords(20);

    final preferences = await SharedPreferences.getInstance();
    expect(state.dailyNewWords, 20);
    expect(preferences.getInt('daily_new_words_v1'), 20);
  });
}
