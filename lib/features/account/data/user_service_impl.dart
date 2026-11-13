// 由 Claude 团队生成 | Monster Word App
// UserServiceImpl — 用户服务实现

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';

import 'package:word_app/models/user_info_bean.dart';
// R3-D06：原先此处是 `hide UserInfoBean`——因为 app_preferences 里有个**同名副本**
// （不做凭证剥离就直接写 SP）。该副本已按审计结论整体删除，hide 随之取消。
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/account/data/user_service.dart';

/// 用户服务实现
///
/// P3-7（架构审计 2026-11-12）：原经 UserRepository 的 Map 版用户信息（键 user_info_v1）
/// 与统计/笔记方法全仓零调用，已连同 UserRepository 层一并删除。本服务只保留
/// Bean 读写——用户信息单一事实来源（键 monster_word_user_info）。
class UserServiceImpl implements UserService {
  // 审计 I62：key 单一事实来源（app_preferences.dart）
  static const _userInfoKey = kUserInfoPrefsKey;

  @override
  Future<UserInfoBean> getUserInfoBean() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userInfoKey);
    if (jsonStr == null || jsonStr.isEmpty) return UserInfoBean();
    try {
      return UserInfoBean.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (e, s) {
      reportSwallowedError('用户信息解析失败', e, s);
      return UserInfoBean();
    }
  }

  @override
  Future<bool> setUserInfoBean(UserInfoBean bean) async {
    // 安全审计 S1：token/secret 只入平台安全存储，SharedPreferences 不落凭证
    if (bean.token.isNotEmpty) {
      await SecureTokenStorage().setToken(bean.token);
    }
    if (bean.secret.isNotEmpty) {
      await SecureTokenStorage().setSecret(bean.secret);
    }
    final sanitized = UserInfoBean.fromJson(bean.toJson())
      ..token = ''
      ..secret = '';
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_userInfoKey, jsonEncode(sanitized.toJson()));
  }
}
