import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/application/restore_cache_reset.dart';
import 'package:word_app/features/scare_coin/application/answer_reward.dart';
import 'package:word_app/features/scare_coin/application/check_in_calendar.dart';
import 'package:word_app/features/scare_coin/application/coin_ledger.dart';
import 'package:word_app/features/scare_coin/application/protection_card.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/features/scare_coin/data/preferences_scare_coin_store.dart';

/// 第三轮 T27：账本实例提升为**顶层单例**——旧实现每次 WordApp.build 都
/// new PreferencesScareCoinStore 经 .value 换值，根重建（热重载/detach 后
/// re-attach）时实例被替换，实例级 _writeQueue 串行闸与 _degradeToSp 粘性
/// 标志归零，旧实例在途写与新实例并发（TOCTOU 闸短暂失效）。顶层 final
/// 惰性单例跨 build 稳定，与进程内其它静态单例（音频/台词）同生命周期口径。
final PreferencesScareCoinStore _store = PreferencesScareCoinStore();

/// 第四轮审计 M18（2026-11-17）：备份恢复后复位金币降级裁决态——旧库触发的
/// 粘性降级对新库不成立（详见 resetDegradationForRestore 注释）。顶层单例
/// 与进程同生命周期，登记一次即可（register 幂等）。
void _registerRestoreReset() {
  RestoreCacheResetBus.register(() async => _store.resetDegradationForRestore());
}

/// 装配尖叫币功能域：单实例 + 聚合门面 + 4 窄端口别名（结构修复步骤4）。
///
/// 关键：**一个实现实例**经 Provider.value 暴露为 5 种类型——共享串行闸/降级
/// 标志/时钟回拨水位不被拆散。窄端口别名用 Provider.value（不另起 create 嵌套
/// 层），REG-ARCH-003 的链序与层数不变。新消费方按需 read 窄端口。
Widget buildScareCoinFeatureScope({required Widget child}) {
  _registerRestoreReset();
  final store = _store;
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
