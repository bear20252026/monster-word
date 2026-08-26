// 由 Claude 团队生成 | Monster Word App
// UserRepository — 用户数据访问抽象

/// 用户数据仓库接口
/// 
/// 提供用户信息、学习统计、签到记录等数据访问抽象。
abstract class UserRepository {
  /// 获取用户信息
  Future<Map<String, dynamic>?> getUserInfo();

  /// 更新用户信息
  Future<int> updateUserInfo(Map<String, dynamic> info);

  /// 获取学习统计
  Future<Map<String, dynamic>> getLearningStats();

  /// 获取签到记录
  Future<List<DateTime>> getCheckInRecords();

  /// 添加签到记录
  Future<int> addCheckIn(DateTime date);

  /// 获取连续签到天数
  Future<int> getStreakDays();

  /// 获取设置项
  Future<String?> getSetting(String key);

  /// 保存设置项
  Future<int> saveSetting(String key, String value);
}
