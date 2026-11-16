import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/checkin/application/belly_interest_store.dart';
import 'package:word_app/features/checkin/application/check_in_history_reader.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/checkin/application/checkin_writer.dart';
import 'package:word_app/features/checkin/data/scare_coin_check_in_history_reader.dart';
import 'package:word_app/features/checkin/data/scare_coin_checkin_status_reader.dart';
import 'package:word_app/features/checkin/data/scare_coin_checkin_writer.dart';
import 'package:word_app/features/scare_coin/application/check_in_calendar.dart';

/// 装配签到功能域所需的全部应用端口。
///
/// 签到事实单一来源为 [CheckInCalendar] 窄端口（上游 [8] ScareCoin 作用域，
/// 结构修复步骤4：从上帝端口 ScareCoinStore 收窄），适配器仅做端口转译，
/// 不持有第二套持久化。presentation 层通过 Provider 获取，不绕过依赖方向。
Widget buildCheckInFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      Provider<CheckInHistoryReader>(
        create: (context) => ScareCoinCheckInHistoryReader(store: context.read<CheckInCalendar>()),
      ),
      Provider<CheckinStatusReader>(
        create: (context) => ScareCoinCheckinStatusReader(store: context.read<CheckInCalendar>()),
      ),
      Provider<CheckinWriter>(create: (context) => ScareCoinCheckinWriter(store: context.read<CheckInCalendar>())),
      // P2-1（架构审计 2026-11-12）：计息存储经 Provider 注入，页面不再兜底直建。
      Provider<BellyInterestStore>(create: (_) => BellyInterestStore()),
    ],
    child: child,
  );
}
