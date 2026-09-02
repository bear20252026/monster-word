import 'package:word_app/features/checkin/application/checkin_writer.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';

/// 基于尖叫币账本（单一事实来源）的签到写入适配器。
///
/// [ScareCoinStore.checkIn] 返回 null 表示今天已签到（幂等），非 null 为签到后的新余额。
class ScareCoinCheckinWriter implements CheckinWriter {
  ScareCoinCheckinWriter({required this._store});

  final ScareCoinStore _store;

  @override
  Future<bool> checkIn() async => (await _store.checkIn()) != null;

  @override
  Future<int> getStreak() => _store.streak();
}
