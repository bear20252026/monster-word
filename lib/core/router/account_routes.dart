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
import 'package:word_app/features/checkin/presentation/check_in_history_page.dart';
import 'package:word_app/features/learning/presentation/dashboard_page.dart';
import 'package:word_app/features/learning/presentation/personal_stereo_page.dart';
import 'package:word_app/features/learning/presentation/play_order_page.dart';
import 'package:word_app/features/scare_coin/presentation/redemption_center_page.dart';
import 'package:word_app/features/scare_coin/presentation/scare_coin_history_page.dart';
import 'package:word_app/features/settings/presentation/design_language_select_page.dart';
import 'package:word_app/features/settings/presentation/more_settings_page.dart';
import 'package:word_app/features/settings/presentation/net_diagnosis_page.dart';
import 'package:word_app/features/settings/presentation/settings_page.dart';
import 'package:word_app/features/settings/presentation/ui_theme_select_page.dart';
import 'package:word_app/features/word_browse/presentation/foot_mark_page.dart';
import 'package:word_app/core/router/route_names.dart';

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
      case RouteNames.designLanguage:
        return const DesignLanguageSelectPage();
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
