import '../../../data/app_preferences.dart';
import '../application/search_history_store.dart';

/// 基于既有应用偏好存储的搜索历史适配器。
class PreferencesSearchHistoryStore implements SearchHistoryStore {
  PreferencesSearchHistoryStore(this._preferences);

  final AppPreferences _preferences;

  @override
  List<String> read() => _preferences.getSearchHistory();

  @override
  Future<void> add(String word) => _preferences.addSearchHistory(word);

  @override
  Future<void> clear() => _preferences.clearSearchHistory();
}
