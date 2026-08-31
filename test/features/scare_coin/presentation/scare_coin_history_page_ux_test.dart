//
// 尖叫币历史页 — UX-FIX-E 测试
//
// 验证 F-3：空态含「去签到」按钮
// 验证 F-7：正负 delta 用图标/文字前缀（不纯靠颜色）

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/features/scare_coin/presentation/scare_coin_history_page.dart';
import 'package:word_app/models/scare_coin_entry.dart';

class _FakeScareCoinStore implements ScareCoinStore {
  final int _balance;
  final bool _checkedToday = false;
  final List<ScareCoinEntry> _entries;

  _FakeScareCoinStore({this._balance = 0, List<ScareCoinEntry>? entries})
      : _entries = entries ?? [];

  @override
  int get checkInReward => 10;

  @override
  Future<int> balance() async => _balance;

  @override
  Future<int?> checkIn() async {
    if (_checkedToday) return null;
    return _balance + checkInReward;
  }

  @override
  Future<int> grant({required int delta, required String reason}) async {
    return _balance + delta;
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
  group('ScareCoinHistoryPage UX-FIX-E', () {
    testWidgets('空态含「去签到」按钮', (tester) async {
      final store = _FakeScareCoinStore(balance: 0, entries: []);

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<ScareCoinStore>.value(
            value: store,
            child: const ScareCoinHistoryPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证空态文案
      expect(find.text('还没有记录，先去签到吧～'), findsOneWidget);
      // 验证「去签到」按钮存在
      expect(find.widgetWithText(OutlinedButton, '去签到'), findsOneWidget);
    });

    testWidgets('正负 delta 用图标区分（不纯靠颜色）', (tester) async {
      final entries = [
        ScareCoinEntry(time: DateTime.now(), delta: 10, reason: '每日签到'),
        ScareCoinEntry(time: DateTime.now(), delta: -5, reason: '兑换主题'),
      ];
      final store = _FakeScareCoinStore(balance: 5, entries: entries);

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<ScareCoinStore>.value(
            value: store,
            child: const ScareCoinHistoryPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证正 delta 有 trending_up 图标
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
      // 验证负 delta 有 trending_down 图标
      expect(find.byIcon(Icons.trending_down), findsOneWidget);
    });
  });
}
