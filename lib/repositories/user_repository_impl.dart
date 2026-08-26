// 由 Claude 团队生成 | Monster Word App
// UserRepositoryImpl — 用户数据仓库实现（使用 SharedPreferences）

import 'package:shared_preferences/shared_preferences.dart';
import 'user_repository.dart';

/// 用户数据仓库的具体实现
///
/// 使用 SharedPreferences 存储用户数据（与现有 LearningState 保持一致）
class UserRepositoryImpl implements UserRepository {
  static const _userInfoKey = 'user_info_v1';
  static const _checkInRecordsKey = 'check_in_records_v1';
  static const _streakKey = 'streak_days_v1';

  @override
  Future<Map<String, dynamic>?> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userInfoKey);
    if (raw == null) return null;
    return {'info': raw};
  }

  @override
  Future<int> updateUserInfo(Map<String, dynamic> info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userInfoKey, info.toString());
    return 1;
  }

  @override
  Future<Map<String, dynamic>> getLearningStats() async {
    // 从 LearningState 读取统计（已持久化到 SharedPreferences）
    return {
      'totalWords': 0,
      'mastered': 0,
      'learning': 0,
      'reviewing': 0,
    };
  }

  @override
  Future<List<DateTime>> getCheckInRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final records = prefs.getStringList(_checkInRecordsKey) ?? [];
    return records.map((r) => DateTime.tryParse(r) ?? DateTime.now()).toList();
  }

  @override
  Future<int> addCheckIn(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final records = prefs.getStringList(_checkInRecordsKey) ?? [];
    final dateStr = date.toIso8601String().split('T').first;
    if (!records.contains(dateStr)) {
      records.add(dateStr);
      await prefs.setStringList(_checkInRecordsKey, records);
    }
    return 1;
  }

  @override
  Future<int> getStreakDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  @override
  Future<String?> getSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('setting_$key');
  }

  @override
  Future<int> saveSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('setting_$key', value);
    return 1;
  }
}
