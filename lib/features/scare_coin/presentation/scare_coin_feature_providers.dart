import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/scare_coin/application/answer_reward.dart';
import 'package:word_app/features/scare_coin/application/check_in_calendar.dart';
import 'package:word_app/features/scare_coin/application/coin_ledger.dart';
import 'package:word_app/features/scare_coin/application/protection_card.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/features/scare_coin/data/preferences_scare_coin_store.dart';

/// 装配尖叫币功能域：单实例 + 聚合门面 + 4 窄端口别名（结构修复步骤4）。
///
/// 关键：**一个实现实例**经 Provider.value 暴露为 5 种类型——共享串行闸/降级
/// 标志/时钟回拨水位不被拆散。窄端口别名用 Provider.value（不另起 create 嵌套
/// 层），REG-ARCH-003 的链序与层数不变。新消费方按需 read 窄端口。
Widget buildScareCoinFeatureScope({required Widget child}) {
  final store = PreferencesScareCoinStore();
  return Provider<ScareCoinStore>.value(
    value: store,
    child: Provider<CoinLedger>.value(
      value: store,
      child: Provider<CheckInCalendar>.value(
        value: store,
        child: Provider<ProtectionCard>.value(
          value: store,
          child: Provider<AnswerReward>.value(value: store, child: child),
        ),
      ),
    ),
  );
}
