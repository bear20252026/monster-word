// 设置状态 ViewModel — 设置、偏好
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置状态 ViewModel
///
/// 负责管理应用设置、用户偏好。
/// 通过 SharedPreferences 持久化设置。
class SettingsState extends ChangeNotifier {
  int _dailyNewWords = 10;
  bool _autoPlayAudio = true;
  bool _showPhonetic = true;
  bool _darkMode = false;
  bool _initialized = false;

  static const _dailyNewWordsKey = 'daily_new_words_v1';
  static const _autoPlayAudioKey = 'auto_play_audio_v1';
  static const _showPhoneticKey = 'show_phonetic_v1';
  static const _darkModeKey = 'dark_mode_v1';

  int get dailyNewWords => _dailyNewWords;
  bool get autoPlayAudio => _autoPlayAudio;
  bool get showPhonetic => _showPhonetic;
  bool get darkMode => _darkMode;
  bool get initialized => _initialized;

  /// 初始化设置
  Future<void> init() async {
    await _loadSettings();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dailyNewWords = prefs.getInt(_dailyNewWordsKey) ?? 10;
      _autoPlayAudio = prefs.getBool(_autoPlayAudioKey) ?? true;
      _showPhonetic = prefs.getBool(_showPhoneticKey) ?? true;
      _darkMode = prefs.getBool(_darkModeKey) ?? false;
    } catch (e) {
      debugPrint('[SettingsState] load error: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_dailyNewWordsKey, _dailyNewWords);
      await prefs.setBool(_autoPlayAudioKey, _autoPlayAudio);
      await prefs.setBool(_showPhoneticKey, _showPhonetic);
      await prefs.setBool(_darkModeKey, _darkMode);
    } catch (e) {
      debugPrint('[SettingsState] save error: $e');
    }
  }

  /// 设置每日新学词数
  Future<void> setDailyNewWords(int value) async {
    if (value == _dailyNewWords) return;
    _dailyNewWords = value;
    await _saveSettings();
    notifyListeners();
  }

  /// 设置自动播放音频
  Future<void> setAutoPlayAudio(bool value) async {
    if (value == _autoPlayAudio) return;
    _autoPlayAudio = value;
    await _saveSettings();
    notifyListeners();
  }

  /// 设置是否显示音标
  Future<void> setShowPhonetic(bool value) async {
    if (value == _showPhonetic) return;
    _showPhonetic = value;
    await _saveSettings();
    notifyListeners();
  }

  /// 设置深色模式
  Future<void> setDarkMode(bool value) async {
    if (value == _darkMode) return;
    _darkMode = value;
    await _saveSettings();
    notifyListeners();
  }
}
