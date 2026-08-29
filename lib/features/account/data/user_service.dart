// 由 Claude 团队生成 | Monster Word App
// UserService — 用户状态管理

import '../../../models/user_info_bean.dart';

/// 用户服务接口
abstract class UserService {
  /// 获取用户信息（Map 格式）
  Future<Map<String, dynamic>?> getUserInfo();

  /// 更新用户信息（Map 格式）
  Future<void> updateUserInfo(Map<String, dynamic> info);

  /// 获取用户信息（UserInfoBean 格式）
  Future<UserInfoBean> getUserInfoBean();

  /// 更新用户信息（UserInfoBean 格式）
  Future<bool> setUserInfoBean(UserInfoBean bean);

  /// 获取学习统计
  Future<Map<String, dynamic>> getLearningStats();

  /// 获取笔记列表
  Future<List<Map<String, dynamic>>> getNotes(int wordId);

  /// 添加笔记
  Future<void> addNote(int wordId, String content);

  /// 删除笔记
  Future<void> deleteNote(int noteId);
}
