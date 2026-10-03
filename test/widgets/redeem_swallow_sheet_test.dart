// RedeemSwallowSheet 兑换成交吞币仪式弹层：渲染与关闭测试（G5b）。
// 纯展示组件：不装配 ScareCoinStore，无账务路径可测。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/coin_swallow_celebration.dart';
import 'package:word_app/widgets/monster_icon.dart';
import 'package:word_app/widgets/redeem_swallow_sheet.dart';

/// 经真实 showRedeemSwallowSheet 入口打开弹层（覆盖 modal 路由装配）。
Future<void> _openSheet(WidgetTester tester, {required int coinCost, required String itemName}) async {
  await tester.pumpWidget(
    SkinProvider(
      skin: SkinSystem(),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () =>
                    showRedeemSwallowSheet(context, itemName: itemName, coinCost: coinCost, monsterStage: 0),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pump(); // 弹层入场首帧
}

void main() {
  testWidgets('弹层渲染：标题/怪兽/itemName/币数行/收下按钮', (tester) async {
    await _openSheet(tester, coinCost: 300, itemName: '暖橙收藏章');
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('收入囊中！'), findsOneWidget);
    expect(find.text('暖橙收藏章'), findsOneWidget);
    expect(find.text('兑换成功 · 300 币'), findsOneWidget);
    expect(find.text('收下！'), findsOneWidget);
    expect(find.byType(MonsterIcon), findsOneWidget);

    // 喂食总时长 2040ms：推进到播完收尾，避免测试结束时 ticker 未停。
    await tester.pump(const Duration(milliseconds: 2500));
  });

  testWidgets('币枚数：超 12 枚截断为 12 枚实飞 + 「+N」徽标', (tester) async {
    await _openSheet(tester, coinCost: 300, itemName: '暖橙收藏章');
    await tester.pump(const Duration(milliseconds: 50));

    // 金币全程挂载、透明度控制显隐，任意时刻都能数到 12 枚。
    expect(tester.widgetList<CoinBadge>(find.byType(CoinBadge)).length, 12);
    expect(find.text('+288'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
  });

  testWidgets('币枚数：小额花费全部实飞，无截断徽标', (tester) async {
    await _openSheet(tester, coinCost: 3, itemName: '纪念小章');
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.widgetList<CoinBadge>(find.byType(CoinBadge)).length, 3);
    expect(find.textContaining('+'), findsNothing);

    // 3 枚总时长 960ms，同样推进到播完。
    await tester.pump(const Duration(milliseconds: 1500));
  });

  testWidgets('「收下！」关闭弹层', (tester) async {
    await _openSheet(tester, coinCost: 800, itemName: '萌系徽章');
    // 泵完入场动画（250ms）：isScrollControlled 后滑行距离变长，
    // 过早 tap 时按钮仍在屏外。
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('收入囊中！'), findsOneWidget);

    await tester.tap(find.text('收下！'));
    await tester.pump(); // 退出动画启动
    await tester.pump(const Duration(seconds: 1)); // 底部弹层退出完成
    expect(find.text('收入囊中！'), findsNothing);
  });
}
