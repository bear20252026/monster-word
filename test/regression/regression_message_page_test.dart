// 由 Claude 团队生成 | Monster Word App

// REG-MSG-001：消息页不得在 build 期间调用 setState（旧版在 itemBuilder 里
// 触发 _loadMessages() 导致「setState called during build」风险）。
// REG-MSG-002：全部已读按钮真实生效（未读数清零、按钮随未读数消失）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/account/application/message_store.dart';
import 'package:word_app/features/account/presentation/message_page.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/checkin/domain/checkin_status.dart';

class _FakeCheckinReader implements CheckinStatusReader {
  @override
  Future<CheckinStatus> getStatus() async =>
      const CheckinStatus(todayChecked: false, streakDays: 2, totalDays: 5, reward: 5);

  @override
  Future<Set<String>> getCheckinDates() async => <String>{};

  @override
  Future<int> getStreakDays() async => 2;

  @override
  Future<bool> hasCheckedInToday() async => false;
}

Widget _wrap(Widget child, MessageStore store) {
  return MultiProvider(
    providers: <SingleChildWidget>[ChangeNotifierProvider<MessageStore>.value(value: store)],
    builder: (BuildContext context, Widget? inner) => MaterialApp(home: inner ?? child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('REG-MSG-001: 消息页裸 push 渲染真实消息列表，无 build 期间 setState 异常', (WidgetTester tester) async {
    final store = MessageStore(checkinReader: _FakeCheckinReader());
    await tester.pumpWidget(_wrap(const MessagePage(), store));
    await tester.pumpAndSettle();

    // 加载完成后：欢迎消息 + 当日打卡提醒（未打卡）都渲染。
    expect(find.text('欢迎来到 Monster Word'), findsOneWidget);
    expect(find.text('今日打卡提醒'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('REG-MSG-002: 全部已读按钮清零未读后消失', (WidgetTester tester) async {
    final store = MessageStore(checkinReader: _FakeCheckinReader());
    await tester.pumpWidget(_wrap(const MessagePage(), store));
    await tester.pumpAndSettle();

    expect(store.unreadCount, greaterThan(0));
    expect(find.textContaining('全部已读'), findsOneWidget);

    await tester.tap(find.textContaining('全部已读'));
    await tester.pumpAndSettle();

    expect(store.unreadCount, 0);
    expect(find.textContaining('全部已读'), findsNothing);
  });
}
