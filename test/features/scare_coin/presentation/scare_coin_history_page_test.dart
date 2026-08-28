// 由 Claude 团队生成 | Monster Word App
//
// 尖叫币历史页 — 呈现层测试
//
// 验证 ScareCoinHistoryPage 在功能域内的渲染与交互：
// - 余额与签到按钮正确渲染
// - 签到成功 / 已签到 两种分支
// - 历史流水列表渲染

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:word_app/core/scare_coin/scare_coin_store.dart';
import 'package:word_app/features/scare_coin/presentation/scare_coin_history_page.dart';
import 'package:word_app/models/scare_coin_entry.dart';

/// 内存假实现：验证页面行为而无需 SharedPreferences。
/// ScareCoinStore 是纯接口（非 ChangeNotifier），故直接 implements。
class FakeScareCoinStore implements ScareCoinStore {
  int _balance;
  bool _checkedToday;
  final List<ScareCoinEntry> _entries;

  FakeScareCoinStore({this._balance = 0, this._checkedToday = false, List<ScareCoinEntry>? entries})
      : _entries = entries ?? [];

  @override
  int get checkInReward => 10;

  @override
  Future<int> balance() async => _balance;

  @override
  Future<int?> checkIn() async {
    if (_checkedToday) return null;
    _checkedToday = true;
    _balance += checkInReward;
    _entries.insert(0, ScareCoinEntry(time: DateTime.now(), delta: checkInReward, reason: '每日签到'));
    return _balance;
  }

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
  Future<String> lastCheckInDate() async => _checkedToday ? DateTime.now().toIso8601String() : '';

  @override
  bool isSameDay(String isoDate, DateTime time) {
    if (isoDate.isEmpty) return false;
    final a = DateTime.tryParse(isoDate);
    if (a == null) return false;
    return a.year == time.year && a.month == time.month && a.day == time.day;
  }

  @override
  Future<int> streak() async => 0;
}

Widget _buildTestPage(ScareCoinStore store) {
  return MaterialApp(
    home: Provider<ScareCoinStore>.value(
      value: store,
      child: const ScareCoinHistoryPage(),
    ),
  );
}

void main() {
  group('ScareCoinHistoryPage', () {
    testWidgets('渲染余额卡与签到按钮', (tester) async {
      final store = FakeScareCoinStore(balance: 20, checkedToday: false);
      await tester.pumpWidget(_buildTestPage(store));
      await tester.pumpAndSettle();

      expect(find.text('我的尖叫币'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('签到 +10'), findsOneWidget);
      expect(find.text('获取记录'), findsOneWidget);
    });

    testWidgets('签到成功后余额更新并显示 SnackBar', (tester) async {
      final store = FakeScareCoinStore(balance: 0, checkedToday: false);
      await tester.pumpWidget(_buildTestPage(store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('签到 +10'));
      await tester.pump(); // checkIn 异步
      await tester.pumpAndSettle();

      // 签到后余额 +10
      expect(find.text('10'), findsOneWidget);
      // SnackBar 提示
      expect(find.textContaining('签到成功'), findsOneWidget);
    });

    testWidgets('已签到后按钮置灰并提示', (tester) async {
      final store = FakeScareCoinStore(balance: 10, checkedToday: true);
      await tester.pumpWidget(_buildTestPage(store));
      await tester.pumpAndSettle();

      // 按钮 onPressed 为 null（已签到）
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('历史流水正确渲染', (tester) async {
      final entries = [
        ScareCoinEntry(time: DateTime(2025, 3, 1, 9, 30), delta: 10, reason: '每日签到'),
        ScareCoinEntry(time: DateTime(2025, 3, 2, 10, 0), delta: 5, reason: '奖励'),
      ];
      final store = FakeScareCoinStore(balance: 15, checkedToday: true, entries: entries);
      await tester.pumpWidget(_buildTestPage(store));
      await tester.pumpAndSettle();

      expect(find.text('每日签到'), findsOneWidget);
      expect(find.text('奖励'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
    });

    testWidgets('空记录显示空态文案', (tester) async {
      final store = FakeScareCoinStore(balance: 0, checkedToday: false, entries: []);
      await tester.pumpWidget(_buildTestPage(store));
      await tester.pumpAndSettle();

      expect(find.text('还没有记录，先去签到吧～'), findsOneWidget);
    });
  });
}
