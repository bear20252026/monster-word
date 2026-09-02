import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/models/scare_coin_entry.dart';

/// 测试替身：尖叫币账本（签到单一事实来源）。
class FakeScareCoinStore implements ScareCoinStore {
  String lastCheckIn = '';
  Set<String> dates = {};
  int streakDays = 0;
  int reward = 10;
  int? checkInResult = 10;

  @override
  int get checkInReward => reward;

  @override
  Future<int> balance() async => 0;

  @override
  Future<Set<String>> checkinDates() async => dates;

  @override
  Future<int> streak() async => streakDays;

  @override
  Future<List<ScareCoinEntry>> history() async => const [];

  @override
  Future<String> lastCheckInDate() async => lastCheckIn;

  @override
  bool isSameDay(String isoDate, DateTime time) => isoDate == isoOf(time);

  @override
  Future<int?> checkIn() async {
    if (isSameDay(lastCheckIn, DateTime.now())) return null;
    lastCheckIn = isoOf(DateTime.now());
    dates = {...dates, lastCheckIn};
    return checkInResult;
  }

  @override
  Future<int> grant({required int delta, required String reason}) async => 0;

  static String isoOf(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
