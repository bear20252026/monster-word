// 聚宝日历签到页冒烟测试：构建 / 签到结算 / 余额联动。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:word_app/widgets/treasure_checkin_page.dart';
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
}
