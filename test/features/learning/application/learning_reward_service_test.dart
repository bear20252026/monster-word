// LearningRewardService 单元测试 — 尖叫币经济防刷规则。
//
// 验证规则（方案 A，2026-08-31 用户批准）：
// R1 会话奖励：本会话 <10 词不发；>=10 词 +5
// R2 会话奖励每自然日上限 3 次（15 币）
// R3 目标达成奖励 +20，每自然日仅一次
// R4 组合：首次结算可同时拿会话+目标奖励
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/learning/application/learning_reward_service.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/models/scare_coin_entry.dart';

class _FakeStore implements ScareCoinStore {
  int coins = 0;
  final List<String> reasons = [];

  @override
  int get checkInReward => 10;

  @override
  Future<int> balance() async => coins;

  @override
  Future<int?> checkIn() async => null;

  @override
  Future<int> grant({required int delta, required String reason}) async {
    coins += delta;
    reasons.add(reason);
    return coins;
  }

  @override
  Future<Set<String>> checkinDates() async => {};

  @override
  Future<List<ScareCoinEntry>> history() async => const [];

  @override
  Future<String> lastCheckInDate() async => '';

  @override
  bool isSameDay(String isoDate, DateTime time) => false;

  @override
  Future<int> streak() async => 0;
}

void main() {
  late _FakeStore store;
  late LearningRewardService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = _FakeStore();
    service = LearningRewardService(store);
  });

  test('R1: 本会话不足 10 词不发币', () async {
    final result = await service.settleSession(wordsLearned: 9, dailyGoalAchieved: false);
    expect(result.totalGranted, 0);
    expect(store.reasons, isEmpty);
  });

  test('R1: 满 10 词发 +5，reason 为「学习完成」', () async {
    final result = await service.settleSession(wordsLearned: 10, dailyGoalAchieved: false);
    expect(result.totalGranted, 5);
    expect(store.coins, 5);
    expect(store.reasons, ['学习完成']);
  });

  test('R2: 同一自然日会话奖励上限 3 次（15 币）', () async {
    for (var i = 0; i < 5; i++) {
      await service.settleSession(wordsLearned: 20, dailyGoalAchieved: false);
    }
    expect(store.coins, 15); // 3 × 5，第 4、5 次不发
    expect(store.reasons.length, 3);
  });

  test('R3: 目标达成 +20，当日仅一次', () async {
    final first = await service.settleSession(wordsLearned: 3, dailyGoalAchieved: true);
    expect(first.totalGranted, 20);
    expect(first.goalJustAchieved, isTrue);

    // 同日第二次达标不再发
    final second = await service.settleSession(wordsLearned: 3, dailyGoalAchieved: true);
    expect(second.totalGranted, 0);
    expect(second.goalJustAchieved, isFalse);
    expect(store.coins, 20);
  });

  test('R4: 首次结算同时拿会话+目标奖励（+25）', () async {
    final result = await service.settleSession(wordsLearned: 15, dailyGoalAchieved: true);
    expect(result.totalGranted, 25);
    expect(store.coins, 25);
    expect(store.reasons, ['学习完成', '今日目标达成']);
  });
}
