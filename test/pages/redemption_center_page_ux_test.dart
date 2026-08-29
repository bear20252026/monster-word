//
// 兑换中心页 — UX-FIX-E 测试
//
// 验证 F-2：显示真实余额（非硬编码 1280）
// 验证 F-2：余额不足时显示「还差 XX 币」

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:word_app/core/scare_coin/scare_coin_store.dart';
import 'package:word_app/models/scare_coin_entry.dart';
import 'package:word_app/features/scare_coin/presentation/redemption_center_page.dart';

class _FakeScareCoinStore implements ScareCoinStore {
  int _balance;
  final List<ScareCoinEntry> _entries;

  _FakeScareCoinStore({this._balance = 100, List<ScareCoinEntry>? entries})
      : _entries = entries ?? [];

  @override
  int get checkInReward => 10;

  @override
  Future<int> balance() async => _balance;

  @override
  Future<int?> checkIn() async => null;

  @override
  Future<int> grant({required int delta, required String reason}) async {
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
    testWidgets('显示真实余额（非硬编码 1280）', (tester) async {
      const realBalance = 100;
      final store = _FakeScareCoinStore(balance: realBalance);

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<ScareCoinStore>.value(
            value: store,
            child: const RedemptionCenterPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证显示真实余额 100，而非硬编码 1280
      expect(find.text('$realBalance'), findsOneWidget);
      expect(find.text('1280'), findsNothing);
    });

    testWidgets('余额不足时显示「还差 XX 币」', (tester) async {
      // 设置余额为 100，兑换项花费 200（第一个兑换项）
      final store = _FakeScareCoinStore(balance: 100);

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<ScareCoinStore>.value(
            value: store,
            child: const RedemptionCenterPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 找到第一个兑换按钮并点击（按钮显示为「500币」）
      final redeemButton = find.text('500币').first;
      expect(redeemButton, findsOneWidget);
      await tester.tap(redeemButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证显示「还差 XX 币」
      expect(find.textContaining('还差'), findsOneWidget);
      expect(find.textContaining('币'), findsWidgets);
    });
  });
}
