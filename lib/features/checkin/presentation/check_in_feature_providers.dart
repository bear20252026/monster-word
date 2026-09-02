import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/checkin/application/check_in_history_reader.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/checkin/application/checkin_writer.dart';
import 'package:word_app/features/checkin/data/scare_coin_check_in_history_reader.dart';
import 'package:word_app/features/checkin/data/scare_coin_checkin_status_reader.dart';
import 'package:word_app/features/checkin/data/scare_coin_checkin_writer.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';

/// 装配签到功能域所需的全部应用端口。
///
/// 签到事实单一来源为 [ScareCoinStore]（上游 [8] ScareCoin 作用域），
/// 适配器仅做端口转译，不持有第二套持久化。presentation 层通过 Provider 获取，
/// 不绕过依赖方向。
Widget buildCheckInFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      Provider<CheckInHistoryReader>(
        create: (context) => ScareCoinCheckInHistoryReader(store: context.read<ScareCoinStore>()),
      ),
      Provider<CheckinStatusReader>(
        create: (context) => ScareCoinCheckinStatusReader(store: context.read<ScareCoinStore>()),
      ),
      Provider<CheckinWriter>(create: (context) => ScareCoinCheckinWriter(store: context.read<ScareCoinStore>())),
    ],
    child: child,
  );
}
