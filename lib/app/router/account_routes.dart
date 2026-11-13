import 'package:flutter/material.dart';

import 'package:word_app/features/account/presentation/account_info_page.dart';
import 'package:word_app/features/account/presentation/appearance_page.dart';
import 'package:word_app/features/account/presentation/feedback_page.dart';
import 'package:word_app/features/account/presentation/help_page.dart';
import 'package:word_app/features/account/presentation/linked_me_middle_page.dart';
import 'package:word_app/features/account/presentation/login_page.dart';
import 'package:word_app/features/account/presentation/message_page.dart';
import 'package:word_app/features/account/presentation/my_equip_page.dart';
import 'package:word_app/features/account/presentation/my_space_page.dart';
import 'package:word_app/features/account/presentation/user_info_manage_page.dart';
import 'package:word_app/app/router/route_names.dart';

/// 账户与个人中心功能域的页面映射和参数解析。
///
/// P3-1（架构审计 2026-11-12）：原 AccountRoutes 是混 7 域的杂物桶（23 路由），
/// 已按属域拆分——设置类归 SettingsRoutes、钱包/签到归 WalletRoutes、
/// 学习/图鉴/足迹归 MiscRoutes。本表只保留 account 域自有页面。
abstract final class AccountRoutes {
  static Widget? build(String? name, Object? args) {
    switch (name) {
      case RouteNames.mySpace:
        return const MySpacePage();
      case RouteNames.login:
        return const LoginPage();
      case RouteNames.messages:
        return const MessagePage();
      case RouteNames.myEquip:
        return const MyEquipPage();
      case RouteNames.help:
        return const HelpPage();
      case RouteNames.userInfoManage:
        return const UserInfoManagePage();
      case RouteNames.appearance:
        return const AppearancePage();
      case RouteNames.accountInfo:
        return const AccountInfoPage();
      case RouteNames.feedback:
        return const FeedbackPage();
      case RouteNames.linkedMe:
        return _buildLinkedMePage(args);
      default:
        return null;
    }
  }

  static Widget _buildLinkedMePage(Object? args) {
    final map = args is Map<String, dynamic> ? args : null;
    return LinkedMeMiddlePage(word: map?['word'] as String? ?? '', association: map?['association'] as String?);
  }
}
