import 'package:flutter/material.dart';

import 'package:word_app/features/checkin/presentation/check_in_history_page.dart';
import 'package:word_app/features/scare_coin/presentation/redemption_center_page.dart';
import 'package:word_app/features/scare_coin/presentation/scare_coin_history_page.dart';
import 'package:word_app/app/router/route_names.dart';

/// 钱包功能域的页面映射（P3-1 从 AccountRoutes 拆出）。
///
/// 尖叫币流水/兑换属 scare_coin 域；签到历史是钱包的入账日历视图
/// （签到事实来源在钱包域，见 scare_coin_checkin_status_reader），故同表。
abstract final class WalletRoutes {
  static Widget? build(String? name, Object? args) {
    switch (name) {
      case RouteNames.scareCoinHistory:
        return const ScareCoinHistoryPage();
      case RouteNames.redemption:
        return const RedemptionCenterPage();
      case RouteNames.checkInHistory:
        return const CheckInHistoryPage();
      default:
        return null;
    }
  }
}
