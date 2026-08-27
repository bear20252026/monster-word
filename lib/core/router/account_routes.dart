import 'package:flutter/material.dart';

import '../../pages/account_info_page.dart';
import '../../pages/appearance_page.dart';
import '../../pages/check_in_history_page.dart';
import '../../pages/dashboard_page.dart';
import '../../pages/feedback_page.dart';
import '../../pages/foot_mark_page.dart';
import '../../pages/help_page.dart';
import '../../pages/linked_me_middle_page.dart';
import '../../pages/login_page.dart';
import '../../pages/message_page.dart';
import '../../pages/more_settings_page.dart';
import '../../pages/my_equip_page.dart';
import '../../pages/my_space_page.dart';
import '../../pages/net_diagnosis_page.dart';
import '../../pages/personal_stereo_page.dart';
import '../../pages/play_order_page.dart';
import '../../pages/redemption_center_page.dart';
import '../../pages/scare_coin_history_page.dart';
import '../../pages/settings_page.dart';
import '../../pages/ui_theme_select_page.dart';
import '../../pages/user_info_manage_page.dart';
import 'route_names.dart';

/// 账户、个人中心与设置功能域的页面映射和参数解析。
abstract final class AccountRoutes {
  static Widget? build(String? name, Object? args) {
    switch (name) {
      case RouteNames.mySpace:
        return const MySpacePage();
      case RouteNames.dashboard:
        return const DashboardPage();
      case RouteNames.settings:
        return const SettingsPage();
      case RouteNames.scareCoinHistory:
        return const ScareCoinHistoryPage();
      case RouteNames.login:
        return const LoginPage();
      case RouteNames.messages:
        return const MessagePage();
      case RouteNames.footMark:
        return const FootMarkPage();
      case RouteNames.myEquip:
        return const MyEquipPage();
      case RouteNames.help:
        return const HelpPage();
      case RouteNames.netDiagnosis:
        return const NetDiagnosisPage();
      case RouteNames.userInfoManage:
        return const UserInfoManagePage();
      case RouteNames.themeSelect:
        return const UIThemeSelectPage();
      case RouteNames.personalStereo:
        return const PersonalStereoPage();
      case RouteNames.playOrder:
        return const PlayOrderPage();
      case RouteNames.appearance:
        return const AppearancePage();
      case RouteNames.moreSettings:
        return const MoreSettingsPage();
      case RouteNames.accountInfo:
        return const AccountInfoPage();
      case RouteNames.feedback:
        return const FeedbackPage();
      case RouteNames.redemption:
        return const RedemptionCenterPage();
      case RouteNames.checkInHistory:
        return const CheckInHistoryPage();
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
