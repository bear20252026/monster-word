import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/features/scare_coin/data/preferences_scare_coin_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('签到只成功一次并写入余额、日期和流水', () async {
    final store = PreferencesScareCoinStore();

    final firstBalance = await store.checkIn();
    final secondBalance = await store.checkIn();

    expect(firstBalance, store.checkInReward);
    expect(secondBalance, isNull);
    expect(await store.balance(), store.checkInReward);
    expect(await store.checkinDates(), hasLength(1));
    expect(await store.history(), hasLength(1));
  });

  test('奖励流水按时间倒序保存且余额可累计', () async {
    final store = PreferencesScareCoinStore();

    await store.grant(delta: 12, reason: '测试奖励');
    await store.grant(delta: -3, reason: '测试扣除');

    final entries = await store.history();
    expect(await store.balance(), 9);
    expect(entries.map((entry) => entry.reason), ['测试扣除', '测试奖励']);
    expect(entries.map((entry) => entry.delta), [-3, 12]);
  });
}
