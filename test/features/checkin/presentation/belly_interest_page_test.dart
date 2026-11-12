// 肚皮储蓄罐离线计息交互：待结算提示 / 点罐入账 / 同日闸门 / 空罐陪伴 / 失败不软锁。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/checkin/application/belly_interest_store.dart';
import 'package:word_app/features/checkin/domain/belly_interest.dart';
import 'package:word_app/features/checkin/presentation/treasure_checkin_page.dart';
import 'package:word_app/features/learning/application/review_schedule_reader.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/models/word.dart';

import '../data/fake_scare_coin_store.dart';

/// 页面内部用 DateTime.now() 算离开时长，种子时间必须相对真实当前时刻
/// （固定时钟只注入给存储的「结算日」口径，两者同日即可）。
DateTime get _realNow => DateTime.now();

/// 注入存储的固定时钟：取真实今天 9 点，保证与页面同日。
DateTime get _kNow {
  final n = _realNow;
  return DateTime(n.year, n.month, n.day, 9);
}

/// 昨日学习量替身：只覆写 dailyStatsFor，其余走端口默认。
class _StatsReader extends ReviewScheduleReader {
  _StatsReader(this.words);

  final int words;

  @override
  Map<String, int> dailyStatsFor(String day) => {'learn': words, 'review': 0};

  @override
  FsrsCard? cardFor(String word) => null;

  @override
  String getStatusText(FsrsCard card) => '';

  @override
  String getDifficultyText(FsrsCard card) => '';

  @override
  int get todayLearnCount => 0;

  @override
  int get todayReviewCount => 0;

  @override
  int get dueCount => 0;

  @override
  int get activeDateCount => 0;

  @override
  Map<String, int> get memoryStats => const {};

  @override
  List<Word> dueWordsFor(Iterable<Word> words) => const [];
}

/// 今日日历日键（与存储/页面同口径）。
String get _todayKey {
  final n = _realNow;
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

/// 预置「3 小时前在场、今日未结算」的 SP 初值。
Map<String, Object> _seedSeen({DateTime? lastSeen, String? settledDay}) {
  final seen = lastSeen ?? _realNow.subtract(const Duration(hours: 3));
  return {
    BellyInterestStore.stateKey:
        '{"lastSeenMs":${seen.millisecondsSinceEpoch}${settledDay != null ? ',"settledDay":"$settledDay"' : ''}}',
  };
}

Widget _wrap({required FakeScareCoinStore store, int yesterdayWords = 5, Map<String, Object> seed = const {}}) {
  return MultiProvider(
    providers: [
      Provider<ScareCoinStore>.value(value: store),
      Provider<BellyInterestStore>.value(value: BellyInterestStore(now: () => _kNow)),
      // ReviewScheduleReader 是 ChangeNotifier，须用对应 Provider（生产同款）。
      ChangeNotifierProvider<ReviewScheduleReader>.value(value: _StatsReader(yesterdayWords)),
    ],
    child: const MaterialApp(home: TreasureCheckInPage()),
  );
}

Future<void> _boot(
  WidgetTester tester, {
  required FakeScareCoinStore store,
  int yesterdayWords = 5,
  Map<String, Object> seed = const {},
}) async {
  SharedPreferences.setMockInitialValues(seed);
  await AppPreferences().init();
  await tester.pumpWidget(_wrap(store: store, yesterdayWords: yesterdayWords, seed: seed));
  // 无时长 pump：让 _reload → 计息刷新的异步微任务链落定（带时长 pump 只推时钟）。
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('有待结算：罐边提示出现，点罐入账并演出', (tester) async {
    final store = FakeScareCoinStore();
    // 3 小时 × (保底 1 + 昨日 5 词) = 18 币。
    await _boot(tester, store: store, seed: _seedSeen());

    expect(find.text(bellyInterestHint(18)), findsOneWidget);
    await tester.tap(find.byKey(const Key('belly_jar')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(store.balanceValue, 18, reason: '离线计息应幂等入账');
    expect(store.rewardEvents, contains('belly_interest:$_todayKey'));
    expect(find.text(bellyInterestHint(18)), findsNothing, reason: '结算后提示消失');
    // 探头气泡在滑入段（350ms）结束后才开始渲染文本；动画控制器需要
    // 实际帧推进（单次大跳 pump 不够），分帧泵过滑入＋气泡起始段。
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(bellyInterestSettledLine), findsOneWidget, reason: '怪兽探头台词');
    // 推完结算解锁（900ms）与探头演出（1500ms）定时器。
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('同日已结算：不再出现待结算提示', (tester) async {
    final store = FakeScareCoinStore();
    await _boot(
      tester,
      store: store,
      seed: _seedSeen(settledDay: _todayKey),
    );

    expect(find.textContaining('肚皮罐攒了'), findsNothing);
    expect(store.balanceValue, 0);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('昨日零学习也有保底：3 小时 = 3 币', (tester) async {
    final store = FakeScareCoinStore();
    await _boot(tester, store: store, yesterdayWords: 0, seed: _seedSeen());

    expect(find.text(bellyInterestHint(3)), findsOneWidget);
    await tester.tap(find.byKey(const Key('belly_jar')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.balanceValue, 3);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('空罐点击：只给陪伴台词，不入账不落结算标', (tester) async {
    final store = FakeScareCoinStore();
    // 首次进页（无在场记录）：只落标不计息。
    await _boot(tester, store: store);

    expect(find.textContaining('肚皮罐攒了'), findsNothing);
    await tester.tap(find.byKey(const Key('belly_jar')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(store.balanceValue, 0);
    expect(store.rewardEvents, isEmpty);
    // 探头气泡在滑入段结束后才渲染文本；分帧泵过滑入＋气泡起始段。
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(bellyInterestEmptyLine), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('入账失败：提示可见、罐子不软锁（可再点）', (tester) async {
    final store = _GrantBoom();
    await _boot(tester, store: store, seed: _seedSeen());

    await tester.tap(find.byKey(const Key('belly_jar')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('收罐失败了，稍后再点一次吧'), findsOneWidget);
    // 再点一次仍会尝试入账（未软锁）。
    await tester.tap(find.byKey(const Key('belly_jar')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('收罐失败了，稍后再点一次吧'), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
  });
}

/// grantOnce 即抛的替身（模拟账本失效现场，守护 busy 软锁）。
class _GrantBoom extends FakeScareCoinStore {
  @override
  Future<int?> grantOnce({required int delta, required String reason, required String eventKey}) async {
    throw StateError('database_closed');
  }
}
