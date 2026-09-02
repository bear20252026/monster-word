// 由 Claude 团队生成 | Monster Word App
// UserRepositoryImpl — 用户数据仓库实现（使用 SharedPreferences）

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/repositories/user_repository.dart';

/// 用户数据仓库的具体实现
///
/// 使用 SharedPreferences 存储用户数据。
class UserRepositoryImpl implements UserRepository {
  static const _userInfoKey = 'user_info_v1';

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
    // 学习统计由学习域的专用读取状态提供；该兼容仓储暂保留既有零值返回。
    return {'totalWords': 0, 'mastered': 0, 'learning': 0, 'reviewing': 0};
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
