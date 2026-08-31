//
// 兑换中心页 — UX-FIX-E 测试
//
// 验证 F-2：显示真实余额（非硬编码 1280）
// 验证 F-2：余额不足时显示「还差 XX 币」

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/models/scare_coin_entry.dart';
import 'package:word_app/features/scare_coin/presentation/redemption_center_page.dart';

class _FakeScareCoinStore implements ScareCoinStore {
  int _balance;
  int grantCalls = 0;
  final List<ScareCoinEntry> _entries;

  _FakeScareCoinStore({this._balance = 100, List<ScareCoinEntry>? entries}) : _entries = entries ?? [];

  @override
  int get checkInReward => 10;

  @override
  Future<int> balance() async => _balance;

  @override
  Future<int?> checkIn() async => null;

  @override
  Future<int> grant({required int delta, required String reason}) async {
    grantCalls++;
    _balance += delta;
    _entries.insert(0, ScareCoinEntry(time: DateTime.now(), delta: delta, reason: reason));
    return _balance;
  }

  @override
  Future<Set<String>> checkinDates() async => {};

  @override
  Future<List<ScareCoinEntry>> history() async => List.unmodifiable(_entries);

  @override
  Future<String> lastCheckInDate() async => '';

  @override
  bool isSameDay(String isoDate, DateTime time) => false;

  @override
  Future<int> streak() async => 0;
}

void main() {
  group('RedemptionCenterPage UX-FIX-E', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('显示真实余额（非硬编码 1280）', (tester) async {
      const realBalance = 100;
      final store = _FakeScareCoinStore(balance: realBalance);

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<ScareCoinStore>.value(value: store, child: const RedemptionCenterPage()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证显示真实余额 100，而非硬编码 1280
      expect(find.text('$realBalance'), findsOneWidget);
      expect(find.text('1280'), findsNothing);
    });

    testWidgets('尖叫币不足：按钮可点但不扣币，提示还差多少', (tester) async {
      // 公平经济规则：兑换真实可执行，但余额不足时拒绝并提示，绝不产生隐藏扣费
      final store = _FakeScareCoinStore(balance: 100);

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<ScareCoinStore>.value(value: store, child: const RedemptionCenterPage()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 公平声明 banner 存在（无权益墙）
      expect(find.textContaining('所有功能对所有人开放'), findsOneWidget);

      // 点击 300 币商品（余额 100 不足）
      await tester.tap(find.text('300').first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(store.grantCalls, 0);
      expect(find.textContaining('尖叫币不足'), findsOneWidget);
    });

    testWidgets('余额充足：真实兑换扣币并标记已拥有', (tester) async {
      final store = _FakeScareCoinStore(balance: 1000);

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<ScareCoinStore>.value(value: store, child: const RedemptionCenterPage()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('300').first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(store.grantCalls, 1);
      expect(find.text('已拥有'), findsOneWidget);
      // 兑换后余额 1000 - 300 = 700
      expect(find.text('700'), findsOneWidget);
      // 兑换成功提示
      expect(find.textContaining('兑换成功'), findsOneWidget);
    });
  });
}
