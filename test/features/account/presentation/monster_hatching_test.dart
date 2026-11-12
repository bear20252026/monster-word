// MonsterHatchingPage 开局命名仪式：敲三下破壳、名字保存。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/app/router/app_router.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/core/utils/monster_identity_prefs.dart';
import 'package:word_app/core/utils/monster_personality.dart';
import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/features/account/presentation/monster_hatching_page.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// 页面整体可滚动（性格卡让小屏一屏放不下）：点击前先滚到可见。
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Widget _app({VoidCallback? onFinished}) {
  return MaterialApp(
    home: MonsterHatchingPage(onFinished: onFinished),
    // 引导经命名路由串演（R4 路由契约），测试装配同款路由生成。
    onGenerateRoute: (settings) =>
        AppRouter.buildPageRoute(settings, AppRouter.buildPage(settings) ?? const SizedBox.shrink()),
  );
}

/// 引导对话已串演：点「跳过」关闭（跳过也落标，与生产口径一致）。
Future<void> _dismissOnboarding(WidgetTester tester) async {
  await tester.pumpAndSettle();
  if (find.text('跳过').evaluate().isNotEmpty) {
    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences().init();
    MonsterSpeech.resetForTest();
  });

  tearDown(() {
    MonsterIdentityPrefs.resetForTest();
    MonsterSpeech.resetForTest();
  });

  testWidgets('敲三下破壳：裂纹递进 → MonsterIcon 出现 → 保存名字与标记', (tester) async {
    var finished = false;
    await tester.pumpWidget(_app(onFinished: () => finished = true));

    // 初始：蛋（无怪兽本体）。
    expect(find.byType(MonsterIcon), findsNothing);
    expect(find.text('敲三下（0/3）'), findsOneWidget);

    await _tapVisible(tester, find.text('敲三下（0/3）'));
    await _tapVisible(tester, find.text('敲三下（1/3）'));

    // 输入名字。
    await tester.enterText(find.byType(TextField), '阿咕');
    await _tapVisible(tester, find.text('敲三下（2/3）'));

    // 第三下：破壳 → 怪兽出现，按钮换「开始冒险！」。
    expect(find.byType(MonsterIcon), findsOneWidget);
    expect(find.text('开始冒险！'), findsOneWidget);

    await _tapVisible(tester, find.text('开始冒险！'));
    await _dismissOnboarding(tester);
    expect(finished, isTrue);

    // SP 落库断言。
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('monster_name'), '阿咕');
    expect(prefs.getInt('monster_hatched'), 1);
    expect(prefs.getString('monster_birthday'), isNotNull);
  });

  testWidgets('空名字保存为默认「咕噜」', (tester) async {
    await tester.pumpWidget(_app(onFinished: () {}));

    for (final label in ['敲三下（0/3）', '敲三下（1/3）', '敲三下（2/3）']) {
      await _tapVisible(tester, find.text(label));
    }
    await _tapVisible(tester, find.text('开始冒险！'));
    await _dismissOnboarding(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('monster_name'), '咕噜');
  });

  testWidgets('REG-HATCH-001: 保存炸 → 用户可见提示 + 可重试（不静默不软锁）', (tester) async {
    MonsterIdentityPrefs.saveOverride = ({required String name, MonsterPersonality? personality}) async =>
        throw StateError('sp disk full');
    await tester.pumpWidget(_app(onFinished: () {}));

    for (final label in ['敲三下（0/3）', '敲三下（1/3）', '敲三下（2/3）']) {
      await _tapVisible(tester, find.text(label));
    }
    await _tapVisible(tester, find.text('开始冒险！'));

    expect(find.text('名字没记上，再点一次「开始冒险」试试'), findsOneWidget, reason: '保存失败必须有可见反馈');
    expect(find.text('开始冒险！'), findsOneWidget, reason: '按钮不得因异常被永久禁用（_saving 复位）');

    // 修复注入后可重入保存成功。
    MonsterIdentityPrefs.resetForTest();
    await _tapVisible(tester, find.text('开始冒险！'));
    await _dismissOnboarding(tester);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('monster_hatched'), 1, reason: '重试走通真实保存');
  });
}
