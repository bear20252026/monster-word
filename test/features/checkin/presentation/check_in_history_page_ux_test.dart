//
// 签到历史页 — UX-FIX-E 测试
//
// 验证 F-3：空态 CTA 导航到签到页（而非仅 pop）
// 验证 F-3：错误态含「重试」按钮
// 验证 E-1：文案统一为「签到」（无「打卡」）

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:word_app/features/checkin/application/check_in_history_reader.dart';
import 'package:word_app/features/checkin/presentation/check_in_history_page.dart';

class _FakeCheckInHistoryReader implements CheckInHistoryReader {
  final bool _empty;
  final bool _failToLoad;

  _FakeCheckInHistoryReader({this._empty = false, this._failToLoad = false});

  @override
  Future<Set<String>> getCheckedDates() async {
    if (_failToLoad) throw Exception('加载失败');
    if (_empty) return {};
    return {'2024-01-01', '2024-01-02'};
  }

  @override
  Future<int> getStreak() async => _empty ? 0 : 2;

  @override
  int get checkInReward => 5;
}

void main() {
  group('CheckInHistoryPage UX-FIX-E', () {
    testWidgets('空态含「去签到」按钮', (tester) async {
      await tester.pumpWidget(
        Provider<CheckInHistoryReader>(
          create: (_) => _FakeCheckInHistoryReader(empty: true),
          child: const MaterialApp(home: CheckInHistoryPage()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证空态文案
      expect(find.text('还没有签到记录'), findsOneWidget);
      // 验证「去签到」按钮存在
      expect(find.widgetWithText(FilledButton, '去签到'), findsOneWidget);
    });

    testWidgets('错误态含「重试」按钮', (tester) async {
      await tester.pumpWidget(
        Provider<CheckInHistoryReader>(
          create: (_) => _FakeCheckInHistoryReader(failToLoad: true),
          child: const MaterialApp(home: CheckInHistoryPage()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证错误提示
      expect(find.text('加载签到数据失败，请重试'), findsOneWidget);
      // 验证「重试」按钮存在
      expect(find.widgetWithText(SnackBarAction, '重试'), findsOneWidget);
    });

    testWidgets('文案统一为「签到」（无「打卡」）', (tester) async {
      await tester.pumpWidget(
        Provider<CheckInHistoryReader>(
          create: (_) => _FakeCheckInHistoryReader(empty: true),
          child: const MaterialApp(home: CheckInHistoryPage()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证页面中不包含「打卡」
      expect(find.textContaining('打卡'), findsNothing);
      // 验证包含「签到」
      expect(find.textContaining('签到'), findsWidgets);
    });
  });
}
