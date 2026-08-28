// 单元测试：每日学习目标功能
// 复现 bug：未设置每日学习目标时，待学习单词为零

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/data/app_preferences.dart';

void main() {
  group('UserPreferences.dailyGoal', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await UserPreferences().init();
    });

    test('默认每日学习目标应为 10', () {
      final prefs = UserPreferences();
      expect(prefs.getDailyGoal(), 10, reason: '默认每日学习目标应为 10');
    });

    test('应能设置每日学习目标', () async {
      final prefs = UserPreferences();
      await prefs.setDailyGoal(20);
      expect(prefs.getDailyGoal(), 20);
    });

    test('应能设置不同的每日学习目标值', () async {
      final prefs = UserPreferences();

      for (final value in [5, 10, 15, 20, 30, 50]) {
        await prefs.setDailyGoal(value);
        expect(prefs.getDailyGoal(), value, reason: '应能设置每日目标为 $value');
      }
    });

    test('每日学习目标应有最小值限制（至少 1）', () async {
      final prefs = UserPreferences();
      await prefs.setDailyGoal(0);
      // 0 应被限制为最小值 1
      expect(prefs.getDailyGoal(), greaterThanOrEqualTo(1));
    });

    test('每日学习目标应有最大值限制（不超过 200）', () async {
      final prefs = UserPreferences();
      await prefs.setDailyGoal(999);
      // 超大值应被限制为最大值 200
      expect(prefs.getDailyGoal(), lessThanOrEqualTo(200));
    });
  });
}
