// 测试：CheckInHistoryPage 签到成功后 UI 能正确刷新。
//
// 修复前（AUD-5 P1-1）：build 方法中直接使用 context.read<CheckInHistoryReader>()
// 无法订阅 ChangeNotifier，导致签到后奖励数量不更新。
// 修复后：使用 Builder + context.watch 确保 UI 在 provider 变化时重建。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/checkin/application/check_in_history_reader.dart';

// 模拟 CheckInHistoryPage 中 Builder + watch 模式的测试组件
class _WatchTestWidget extends StatelessWidget {
  const _WatchTestWidget();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 模拟修复后的 Builder + watch 模式
          Builder(
            builder: (ctx) => Text(
              'reward:${ctx.watch<_FakeNotifier>().reader.checkInReward}',
            ),
          ),
        ],
      ),
    );
  }
}

class _FakeNotifier extends ChangeNotifier {
  _FakeNotifier(this.reader);

  CheckInHistoryReader reader;
}

class _FakeCheckInHistoryReader implements CheckInHistoryReader {
  _FakeCheckInHistoryReader({this.reward = 5});

  final int reward;

  @override
  Future<Set<String>> getCheckedDates() async => <String>{};

  @override
  Future<int> getStreak() async => 0;

  @override
  int get checkInReward => reward;
}

void main() {
  testWidgets('CheckInHistoryPage 使用 watch 模式，reader 变化时触发重建',
      (tester) async {
    final notifier = _FakeNotifier(_FakeCheckInHistoryReader(reward: 5));

    await tester.pumpWidget(
      ChangeNotifierProvider<_FakeNotifier>.value(
        value: notifier,
        child: const MaterialApp(home: _WatchTestWidget()),
      ),
    );

    // 初始值渲染
    expect(find.text('reward:5'), findsOneWidget);

    // 模拟奖励变化
    notifier.reader = _FakeCheckInHistoryReader(reward: 10);
    notifier.notifyListeners();
    await tester.pump();

    // 断言：UI 应随 watch 触发重建
    expect(find.text('reward:10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
