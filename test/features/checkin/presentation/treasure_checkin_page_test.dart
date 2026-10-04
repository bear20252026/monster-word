// 聚宝日历签到页冒烟测试：构建 / 签到结算 / 余额联动。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/checkin/presentation/treasure_checkin_page.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';

import '../data/fake_scare_coin_store.dart';

/// 带余额口径的替身（签到入账 → balance 反映）。
class _BalanceFake extends FakeScareCoinStore {
  int bal = 0;

  @override
  Future<int> balance() async => bal;

  @override
  Future<int?> checkIn() async {
    final result = await super.checkIn();
    if (result == null) return null;
    bal += result;
    return result;
  }
}

Widget _wrap(_BalanceFake store) => Provider<ScareCoinStore>.value(
  value: store,
  child: const MaterialApp(home: TreasureCheckInPage()),
);

void main() {
  testWidgets('聚宝日历：月份与 CTA 正常呈现', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_wrap(_BalanceFake()));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('${now.year} 年 ${now.month} 月'), findsOneWidget);
    expect(find.text('立即签到 · +10'), findsOneWidget);
    // 今日徽章数字存在（散落/聚合过程中的当日徽章）。
    expect(find.text('${now.day}'), findsOneWidget);
    // 推完入场聚合定时器（散开 700ms → 重组）。
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('聚宝日历：签到后 CTA 变已签、连击与余额联动', (tester) async {
    final store = _BalanceFake();
    await tester.pumpWidget(_wrap(store));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('立即签到 · +10'));
    // 850ms 结算点（余额 / 连击 / CTA 灰化）。
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('今日已签到 · 明天再来'), findsOneWidget);
    expect(find.text('10'), findsWidgets); // 余额胶囊与 +10 浮字
    expect(find.text('1'), findsWidgets); // 连击 1
    // 推完散开-重组（600/850/1900/2800ms）定时器。
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('聚宝日历：已签态不可重复签到', (tester) async {
    final store = _BalanceFake()..streakDays = 3;
    store.dates = {FakeScareCoinStore.isoOf(DateTime.now())};
    await tester.pumpWidget(_wrap(store));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('今日已签到 · 明天再来'), findsOneWidget);
    // 已签态点击不产生新入账。
    await tester.tap(find.text('今日已签到 · 明天再来'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('0'), findsWidgets); // 余额仍为 0
    // 推完入场聚合定时器。
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('进化仪式取数失败：结算照常落定，按钮不软锁（审计 P2-5）', (tester) async {
    await tester.pumpWidget(_wrap(_DatesBoom()));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('立即签到 · +10'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 100));

    // 取 checkinDates 抛错只该让「进化仪式」不演——结算与解锁必须照常，
    // 否则 _busy 永久 true（软锁到重进页面）。
    expect(find.text('今日已签到 · 明天再来'), findsOneWidget, reason: '结算未被异常牵连');
    expect(find.text('10'), findsWidgets); // 余额已入账
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('签到入账失败：按钮不软锁、给出用户可见提示（2026-10-04 审计）', (tester) async {
    await tester.pumpWidget(_wrap(_CheckInBoom()));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('立即签到 · +10'));
    await tester.pump(const Duration(milliseconds: 100));

    // 入账抛错必须复位 _busy 并提示——不能软锁到重进页面、异常只进 zone。
    expect(find.text('签到失败了，稍后再试一次吧'), findsOneWidget, reason: '入账失败要有用户可见反馈');
    expect(find.text('立即签到 · +10'), findsOneWidget, reason: 'CTA 不得因异常被永久禁用');
    // CTA 仍可再次点击（未软锁）。
    await tester.tap(find.text('立即签到 · +10'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('签到失败了，稍后再试一次吧'), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
  });
}

/// 签到入账即抛的替身（模拟 applyDelta 失败/database_closed，守护 2026-10-04 审计的 busy 软锁修复）。
class _CheckInBoom extends _BalanceFake {
  @override
  Future<int?> checkIn() async {
    throw StateError('database_closed');
  }
}

/// 签到后取日期即抛的替身（模拟库失效/句柄关闭现场，守护 P2-5 的错误边界）。
class _DatesBoom extends _BalanceFake {
  bool _checkedIn = false;

  @override
  Future<int?> checkIn() async {
    final result = await super.checkIn();
    if (result != null) _checkedIn = true;
    return result;
  }

  @override
  Future<Set<String>> checkinDates() async {
    if (_checkedIn) throw StateError('database_closed');
    return super.checkinDates();
  }
}
