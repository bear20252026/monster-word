// 回归测试（2026-09-01）：查词页打开即崩溃。
//
// 根因：PreferencesSearchHistoryStore.fromServiceLocator() 走 sl<AppPreferences>()，
// 但 AppPreferences 是工厂单例、从未注册进 GetIt → 首次读 SearchHistoryStore
// 抛 "AppPreferences is not registered"，查词页整页构建失败。
// 修复后工厂直用 AppPreferences()，本测试锁定该行为不回退。
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/search/data/preferences_search_history_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fromServiceLocator 创建不抛 GetIt 异常（AppPreferences 单例直用）', () {
    final store = PreferencesSearchHistoryStore.fromServiceLocator();
    expect(store, isA<PreferencesSearchHistoryStore>());
    // read() 不应抛异常（测试环境下 SharedPreferences 未初始化时也应安全）。
    expect(() => store.read(), returnsNormally);
  });

  test('AppPreferences 为工厂单例（单一事实来源）', () {
    expect(identical(AppPreferences(), AppPreferences()), isTrue);
  });
}
