import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/learning/application/learning_reward_service.dart';
import 'package:word_app/features/scare_coin/application/coin_ledger.dart';
import 'package:word_app/models/scare_coin_entry.dart';

/// 待结算队列存储格式契约（结构修复步骤5b 排查沉淀）：
/// 外层是「JSON 字符串数组」——每个元素本身是条目 JSON 再编码一次的字符串
/// （enqueue 逐条 jsonEncode 后整体 jsonEncode）。直接塞 JSON 对象数组会被
/// _readPending 的 whereType<String> 全部滤掉、按空队列静默处理。
/// 本测试锁定该格式，防未来写入方/预置方口径漂移。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('双层编码条目：结算发币并清空队列', () async {
    final ledger = _Ledger();
    final entry = jsonEncode({'id': 'e1', 'wordsLearned': 12, 'dailyGoalAchieved': false, 'date': '2026-11-16'});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LearningRewardService.pendingKey, jsonEncode([entry]));
    final result = await LearningRewardService(ledger).settlePendingSessions();
    expect(result.totalGranted, 5);
    expect(prefs.getString(LearningRewardService.pendingKey), isNull);
  });

  test('误写对象数组（非字符串元素）：按空队列处理，条目原样保留不崩溃', () async {
    final ledger = _Ledger();
    final wrongFormat = jsonEncode([
      {'id': 'e1', 'wordsLearned': 12, 'dailyGoalAchieved': false, 'date': '2026-11-16'},
    ]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LearningRewardService.pendingKey, wrongFormat);
    final result = await LearningRewardService(ledger).settlePendingSessions();
    expect(result.totalGranted, 0);
    // 空队列早退不清档：坏格式数据保留，等待写入方修复或人工对账。
    expect(prefs.getString(LearningRewardService.pendingKey), wrongFormat);
  });
}

class _Ledger implements CoinLedger {
  int total = 0;
  final Set<String> _keys = {};

  @override
  Future<int> balance() async => total;

  @override
  Future<List<ScareCoinEntry>> history() async => const [];

  @override
  Future<int> grant({required int delta, required String reason}) async {
    total += delta;
    return total;
  }

  @override
  Future<int?> grantOnce({required int delta, required String reason, required String eventKey}) async {
    if (!_keys.add(eventKey)) return null;
    total += delta;
    return total;
  }
}
