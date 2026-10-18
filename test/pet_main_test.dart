// 桌面宠物窗口：Dart 侧契约。
//
// 这个窗口跑在**第二个 Flutter engine** 上（lib/pet_main.dart 的 petMain），
// 与主应用不共享内存，所有交互只能走 MethodChannel。所以这里守的是通道契约：
// 手势 → 方法名 → 参数，一个都不能变，否则宠物会变成一块动不了也关不掉的图片。
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/pet_main.dart';
import 'package:word_app/widgets/monster_icon.dart';

void main() {
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(petWindowChannel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(petWindowChannel, null);
  });

  Future<void> pumpPet(WidgetTester tester, {int? days}) async {
    await tester.pumpWidget(PetWindowApp(launch: PetLaunchArgs(days: days)));
    await tester.pump();
  }

  test('启动参数：days=N 解析，缺失即 null（不知道形态就别猜）', () {
    expect(PetLaunchArgs.parse(['days=12']).days, 12);
    expect(PetLaunchArgs.parse(const []).days, isNull);
    expect(PetLaunchArgs.parse(['days=abc']).days, isNull);
    expect(PetLaunchArgs.parse(['other=3']).days, isNull);
  });

  testWidgets('窗口里没有 Scaffold —— 有它窗口就不透明了', (tester) async {
    await pumpPet(tester);

    expect(find.byType(Scaffold), findsNothing, reason: 'Scaffold 会画一层不透明底色，桌面就透不出来了');
    expect(find.byType(MonsterIcon), findsOneWidget);
  });

  testWidgets('单击说话：冒泡后自己收回去', (tester) async {
    await pumpPet(tester);

    await tester.tap(find.byType(MonsterIcon));
    // 注册了 onDoubleTap ⇒ 单击要等双击超时才成立。
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(Text), findsOneWidget, reason: '点一下必须给反馈，否则用户以为它死了');

    // 2.6s 后气泡自己收（桌面宠物没有「点进去看详情」这条路）
    await tester.pump(const Duration(milliseconds: 3000));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('拖动移动窗口：逻辑位移 × devicePixelRatio', (tester) async {
    await pumpPet(tester);

    await tester.drag(find.byType(MonsterIcon), const Offset(-40, -30));
    // 注册了 onDoubleTap ⇒ 每次按下都会起一个 40ms 的双击计时器，不排掉会报 pending timer。
    await tester.pump(const Duration(milliseconds: 400));

    final moveCalls = calls.where((c) => c.method == 'moveBy').toList();
    expect(moveCalls, isNotEmpty, reason: '无边框窗口没有标题栏，拖动是唯一能挪它的方式');
    final args = moveCalls.last.arguments as List<Object?>;
    expect(args.length, 2);
    final dpr = tester.view.devicePixelRatio;
    // 增量累加后总位移应等于拖动的逻辑位移（× dpr 换成物理像素）。
    var dx = 0.0;
    var dy = 0.0;
    for (final c in moveCalls) {
      final a = c.arguments as List<Object?>;
      dx += (a[0]! as num).toDouble();
      dy += (a[1]! as num).toDouble();
    }
    expect(dx, lessThan(0), reason: '往左拖窗口就得往左走');
    expect(dy, lessThan(0), reason: '往上拖窗口就得往上走');
    // 手势 slop 会吃掉起手那一段（DragStartBehavior.start），所以只断言量级接近。
    expect(dx.abs(), closeTo(40 * dpr, 20 * dpr));
    expect(dy.abs(), closeTo(30 * dpr, 15 * dpr));
  });

  testWidgets('双击打开主应用（宠物不能是「只能看不能进」的孤岛）', (tester) async {
    await pumpPet(tester);

    await tester.tap(find.byType(MonsterIcon));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(MonsterIcon));
    await tester.pump(const Duration(milliseconds: 400));

    expect(calls.any((c) => c.method == 'openApp'), isTrue);
  });

  testWidgets('右键关掉宠物窗口（否则它永远盖在最上面）', (tester) async {
    await pumpPet(tester);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(MonsterIcon)), buttons: kSecondaryButton);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));

    expect(calls.any((c) => c.method == 'close'), isTrue);
  });
}
