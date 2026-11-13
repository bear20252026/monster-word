// 由 Claude 团队生成 | Monster Word App
// UserService — 用户状态管理

import 'package:word_app/models/user_info_bean.dart';

/// 用户服务接口
///
/// P3-7（架构审计 2026-11-12）：原 Map 版 getUserInfo/updateUserInfo、getLearningStats
/// 与笔记三方法全仓零调用，已删除（笔记的活路径在 word_browse 域经 NoteRepository）。
/// 用户信息单一事实来源 = Bean 方法（键 monster_word_user_info，凭证剥离后落 SP）。
abstract class UserService {
  /// 获取用户信息（UserInfoBean 格式）
  Future<UserInfoBean> getUserInfoBean();

  /// 更新用户信息（UserInfoBean 格式）
  Future<bool> setUserInfoBean(UserInfoBean bean);
}
