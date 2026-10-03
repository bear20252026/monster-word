// MonsterHatchingPage 开局命名仪式：敲三下破壳、名字保存。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/account/presentation/monster_hatching_page.dart';
import 'package:word_app/widgets/monster_icon.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('敲三下破壳：裂纹递进 → MonsterIcon 出现 → 保存名字与标记', (tester) async {
    var finished = false;
    await tester.pumpWidget(MaterialApp(home: MonsterHatchingPage(onFinished: () => finished = true)));

    // 初始：蛋（无怪兽本体）。
    expect(find.byType(MonsterIcon), findsNothing);
    expect(find.text('敲三下（0/3）'), findsOneWidget);

    await tester.tap(find.text('敲三下（0/3）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('敲三下（1/3）'));
    await tester.pumpAndSettle();

    // 输入名字。
    await tester.enterText(find.byType(TextField), '阿咕');
    await tester.tap(find.text('敲三下（2/3）'));
    await tester.pumpAndSettle();

    // 第三下：破壳 → 怪兽出现，按钮换「开始冒险！」。
    expect(find.byType(MonsterIcon), findsOneWidget);
    expect(find.text('开始冒险！'), findsOneWidget);

    await tester.tap(find.text('开始冒险！'));
    await tester.pump();
    expect(finished, isTrue);

    // SP 落库断言。
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('monster_name'), '阿咕');
    expect(prefs.getInt('monster_hatched'), 1);
    expect(prefs.getString('monster_birthday'), isNotNull);
  });

  testWidgets('空名字保存为默认「咕噜」', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MonsterHatchingPage()));

    await tester.tap(find.text('敲三下（0/3）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('敲三下（1/3）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('敲三下（2/3）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始冒险！'));
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('monster_name'), '咕噜');
  });
}
