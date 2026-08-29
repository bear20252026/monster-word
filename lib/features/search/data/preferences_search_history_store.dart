import '../../../core/di/service_locator.dart';
import '../../../data/app_preferences.dart';
import '../application/search_history_store.dart';

/// 基于既有应用偏好存储的搜索历史适配器。
class PreferencesSearchHistoryStore implements SearchHistoryStore {
  /// 从 service_locator 自动解析依赖。
  factory PreferencesSearchHistoryStore.fromServiceLocator() =>
      PreferencesSearchHistoryStore._(sl<AppPreferences>());

  PreferencesSearchHistoryStore._(this._preferences);

  /// 显式注入（供测试覆盖）。
  PreferencesSearchHistoryStore(AppPreferences preferences)
      : _preferences = preferences;

  final AppPreferences _preferences;

  @override
  List<String> read() => _preferences.getSearchHistory();

  @override
  Future<void> add(String word) => _preferences.addSearchHistory(word);

  @override
  Future<void> clear() => _preferences.clearSearchHistory();
}
