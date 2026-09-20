import 'package:word_app/core/infrastructure/app_preferences.dart';

/// 主题/皮肤偏好读写门面（theme 层不直触 infrastructure）。
class ThemePrefs {
  ThemePrefs({AppPreferences? prefs}) : _p = prefs ?? AppPreferences();

  final AppPreferences _p;

  String getThemeId() => _p.getSkinThemeId();

  Future<bool> setThemeId(String value) => _p.setSkinThemeId(value);

  bool isFollowSystem() => _p.isSkinFollowSystem();

  Future<bool> setFollowSystem(bool value) => _p.setSkinFollowSystem(value);
}
