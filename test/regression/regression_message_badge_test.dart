// 由 Claude 团队生成 | Monster Word App

// REG-MSG-003：消息中心入口未读角标由 MessageStore 真实驱动——
// 有未读显示数字角标，全部已读后消失；
// 旧版 my_space 入口为硬编码常显红点（无未读也亮红点），本测试钉死该假语义不得回归。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/account/application/message_store.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/message_badge_icon.dart';

Widget _wrap(MessageStore store) {
  return SkinProvider(
    skin: SkinSystem(),
    child: MultiProvider(
      providers: <SingleChildWidget>[ChangeNotifierProvider<MessageStore>.value(value: store)],
      child: const MaterialApp(
        home: Scaffold(body: Center(child: MessageBadgeIcon())),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('REG-MSG-003: 有未读显示数字角标，全部已读后角标消失', (WidgetTester tester) async {
    final store = MessageStore();
    await store.load(); // 首次加载生成欢迎消息 → 未读 1。
    expect(store.unreadCount, greaterThan(0));

    await tester.pumpWidget(_wrap(store));
    await tester.pumpAndSettle();

    // 角标显示未读数字。
    expect(find.text('${store.unreadCount}'), findsOneWidget);

    await store.markAllRead();
    await tester.pumpAndSettle();

    // 旧版假语义：无未读也常显红点；现在角标必须消失。
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('REG-MSG-003b: 未读超过 99 显示 99+', (WidgetTester tester) async {
    final store = MessageStore();
    // 直接构造 100 条未读（不经 load，避免持久化刷新逻辑干扰）。
    store.debugSeedUnread(100);

    await tester.pumpWidget(_wrap(store));
    await tester.pumpAndSettle();

    expect(find.text('99+'), findsOneWidget);
  });
}
