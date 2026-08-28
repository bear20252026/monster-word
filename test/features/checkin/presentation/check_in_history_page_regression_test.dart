// 回归测试：CheckInHistoryPage 曾因「SingleTickerProviderStateMixin 创建了多个
// AnimationController」而在 build 时崩溃（multiple tickers were created）。
//
// 本测试用真实 widget + 注入带数据的 CheckInHistoryReader 泵起整页，断言构建过程
// 不抛任何异常。若该故障回归（例如有人再改回 SingleTickerProviderStateMixin），
// CI 会立即红。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/checkin/application/check_in_history_reader.dart';
import 'package:word_app/features/checkin/presentation/check_in_history_page.dart';

class _FakeCheckInHistoryReader implements CheckInHistoryReader {
  @override
  Future<Set<String>> getCheckedDates() async =>
      <String>{'2024-01-01', '2024-01-02', '2024-01-03'};

  @override
  Future<int> getStreak() async => 3;

  @override
  int get checkInReward => 5;
}

void main() {
  testWidgets('CheckInHistoryPage 不再因多动画控制器而崩溃', (tester) async {
    await tester.pumpWidget(
      Provider<CheckInHistoryReader>(
        create: (_) => _FakeCheckInHistoryReader(),
        child: const MaterialApp(home: CheckInHistoryPage()),
      ),
    );

    // 让 _refresh() 的异步读取完成、入场动画走完。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 900));

    // 核心断言：整页构建/刷新过程中不得抛出任何 FlutterError。
    expect(tester.takeException(), isNull);
  });
}
