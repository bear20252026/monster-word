import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/home/application/home_startup_coordinator.dart';
import 'package:word_app/features/learning/application/learning_reward_service.dart';
import 'package:word_app/features/scare_coin/application/coin_ledger.dart';
import 'package:word_app/features/scare_coin/application/protection_card.dart';

/// 结构修复步骤5b（M4）：首页首帧启动仪式编排的单测。
/// 业务从 app.dart 壳层外移后，判定/持久化/发奖首次可脱离 widget 树整表驱动。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const visitKey = 'test.last_visit';
  const fixedNow = '2026-11-16T10:00:00';

  late _FakeLedger ledger;
  late List<int> reunionCalls;
  late int onboardingCalls;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences().init();
    ledger = _FakeLedger();
    reunionCalls = [];
    onboardingCalls = 0;
  });

  HomeStartupCoordinator build({
    LearningRewardService? rewards,
    ProtectionCard? protection,
    bool Function()? isMounted,
    String? nowIso,
  }) {
    return HomeStartupCoordinator(
      lastVisitPrefKey: visitKey,
      rewards: rewards,
      protection: protection,
      isMounted: isMounted ?? () => true,
      now: () => DateTime.parse(nowIso ?? fixedNow),
      showReunion: reunionCalls.add,
      showOnboarding: () async {
        onboardingCalls++;
      },
    );
  }

  group('runReunionRitual', () {
    test('旧访问 ≥3 天：演出一次 + 保护卡 ×1 + last_visit 刷新为今天', () async {
      await (await SharedPreferences.getInstance()).setString(visitKey, '2026-11-10');
      await build(protection: ledger).runReunionRitual();
      expect(reunionCalls, [6]);
      expect(ledger.protectionAdds, [(count: 1, reason: '回家礼')]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(visitKey), '2026-11-16');
    });

    test('缺席 <3 天：不演出、不发卡，仍刷新 last_visit', () async {
      await (await SharedPreferences.getInstance()).setString(visitKey, '2026-11-14');
      await build(protection: ledger).runReunionRitual();
      expect(reunionCalls, isEmpty);
      expect(ledger.protectionAdds, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(visitKey), '2026-11-16');
    });

    test('坏日期串：按缺席不足处理，不演出但刷新 last_visit', () async {
      await (await SharedPreferences.getInstance()).setString(visitKey, 'not-a-date');
      await build(protection: ledger).runReunionRitual();
      expect(reunionCalls, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(visitKey), '2026-11-16');
    });

    test('保护卡端口缺席：演出照常，发放静默跳过（最小装配）', () async {
      await (await SharedPreferences.getInstance()).setString(visitKey, '2026-11-10');
      await build().runReunionRitual();
      expect(reunionCalls, [6]);
    });

    test('首启（无旧记录）：走引导一次并落闸门标记，不演回家', () async {
      await build(protection: ledger).runReunionRitual();
      expect(onboardingCalls, 1);
      expect(reunionCalls, isEmpty);
      expect(AppPreferences().getOnboardingDone(), isTrue);
    });

    test('首启但已破壳：引导不二弹（命名仪式已串演）', () async {
      await (await SharedPreferences.getInstance()).setInt('monster_hatched', 1);
      await build().runReunionRitual();
      expect(onboardingCalls, 0);
    });

    test('异步 gap 后壳已卸载：不演出（mounted 判定）', () async {
      await (await SharedPreferences.getInstance()).setString(visitKey, '2026-11-10');
      await build(protection: ledger, isMounted: () => false).runReunionRitual();
      expect(reunionCalls, isEmpty);
      expect(ledger.protectionAdds, isEmpty);
    });
  });

  group('drainPendingRewards', () {
    test('结算器缺席（最小装配无账本）：静默跳过，队列原样保留', () async {
      final entry = jsonEncode({'id': 'e1', 'wordsLearned': 12, 'dailyGoalAchieved': false, 'date': '2026-11-16'});
      final seeded = jsonEncode([entry]);
      await (await SharedPreferences.getInstance()).setString(LearningRewardService.pendingKey, seeded);
      await build().drainPendingRewards();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LearningRewardService.pendingKey), seeded);
    });

    test('有待结算条目：经账本幂等发币并清空队列', () async {
      // 队列存储格式是双层编码：外层 JSON 数组的元素是「条目 JSON 字符串」
      // （enqueue 对每条 jsonEncode 后再整体 jsonEncode），预置必须同格式，
      // 否则 _readPending 的 whereType<String> 全部滤掉、按空队列处理。
      final entry = jsonEncode({'id': 'e1', 'wordsLearned': 12, 'dailyGoalAchieved': false, 'date': '2026-11-16'});
      await (await SharedPreferences.getInstance()).setString(LearningRewardService.pendingKey, jsonEncode([entry]));
      await build(rewards: LearningRewardService(ledger)).drainPendingRewards();
      expect(ledger.grantedTotal, 5);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LearningRewardService.pendingKey), isNull);
    });
  });
}

class _FakeLedger implements CoinLedger, ProtectionCard {
  int grantedTotal = 0;
  final List<({int count, String reason})> protectionAdds = [];
  final Set<String> _eventKeys = {};

  @override
  Future<int> grant({required int delta, required String reason}) async {
    grantedTotal += delta;
    return grantedTotal;
  }

  @override
  Future<int?> grantOnce({required int delta, required String reason, required String eventKey}) async {
    if (!_eventKeys.add(eventKey)) return null;
    grantedTotal += delta;
    return grantedTotal;
  }

  @override
  Future<int> addProtection({required int count, required String reason}) async {
    protectionAdds.add((count: count, reason: reason));
    return protectionAdds.length;
  }

  @override
  int get protectionCap => 3;

  @override
  Future<int> protectionCount() async => protectionAdds.length;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
