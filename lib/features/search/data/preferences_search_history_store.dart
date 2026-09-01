import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/search/application/search_history_store.dart';

/// 基于既有应用偏好存储的搜索历史适配器。
class PreferencesSearchHistoryStore implements SearchHistoryStore {
  /// AppPreferences 是工厂单例（全库统一 `AppPreferences()` 直用），
  /// 未注册进 GetIt——不得走 `sl<AppPreferences>()`（2026-09-01 崩溃根因：
  /// 查词页打开即 GetIt 抛 "AppPreferences is not registered" 整页失败）。
  factory PreferencesSearchHistoryStore.fromServiceLocator() => PreferencesSearchHistoryStore._(AppPreferences());

  PreferencesSearchHistoryStore._(this._preferences);

  /// 显式注入（供测试覆盖）。
  PreferencesSearchHistoryStore(AppPreferences preferences) : _preferences = preferences;

  final AppPreferences _preferences;

  @override
  List<String> read() => _preferences.getSearchHistory();

  @override
  Future<void> add(String word) => _preferences.addSearchHistory(word);

  @override
  Future<void> clear() => _preferences.clearSearchHistory();
}
