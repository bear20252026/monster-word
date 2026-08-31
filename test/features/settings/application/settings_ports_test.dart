import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/settings/application/settings_reader.dart';
import 'package:word_app/features/settings/application/settings_writer.dart';
import 'package:word_app/features/settings/domain/learning_preferences.dart';

/// 内存实现，用于端口契约测试
class _InMemorySettings implements SettingsReader, SettingsWriter {
  LearningPreferences _prefs = const LearningPreferences.defaults();

  @override
  Future<LearningPreferences> load() async => _prefs;

  @override
  Future<void> save(LearningPreferences preferences) async {
    _prefs = preferences;
  }
}

void main() {
  group('SettingsReader / SettingsWriter 端口契约', () {
    late _InMemorySettings settings;

    setUp(() {
      settings = _InMemorySettings();
    });

    test('load() 返回默认偏好', () async {
      final loaded = await settings.load();

      expect(loaded.dailyNewWords, 10);
      expect(loaded.autoPlayAudio, isTrue);
      expect(loaded.pronunciationType, '美式');
    });

    test('save() + load() 保持写入数据', () async {
      final prefs = const LearningPreferences.defaults().copyWith(dailyNewWords: 30, darkMode: true, learnPace: 20);

      await settings.save(prefs);
      final loaded = await settings.load();

      expect(loaded.dailyNewWords, 30);
      expect(loaded.darkMode, isTrue);
      expect(loaded.learnPace, 20);
      expect(loaded.autoPlayAudio, isTrue); // 保留默认值
    });

    test('多次 save() 覆盖前次', () async {
      await settings.save(const LearningPreferences.defaults().copyWith(dailyNewWords: 5));
      await settings.save(const LearningPreferences.defaults().copyWith(dailyNewWords: 50));

      final loaded = await settings.load();
      expect(loaded.dailyNewWords, 50);
    });
  });
}
