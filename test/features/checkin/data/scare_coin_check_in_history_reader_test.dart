import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/checkin/data/scare_coin_check_in_history_reader.dart';

import 'fake_scare_coin_store.dart';

void main() {
  test('reads history values and reward from the scare coin ledger', () async {
    final store = FakeScareCoinStore()..dates = {'2026-08-28'};
    store.streakDays = 3;
    final reader = ScareCoinCheckInHistoryReader(store: store);

    expect(await reader.getCheckedDates(), {'2026-08-28'});
    expect(await reader.getStreak(), 3);
    expect(reader.checkInReward, 10);
  });
}
