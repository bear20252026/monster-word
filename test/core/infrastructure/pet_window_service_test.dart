import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/infrastructure/pet_window_service.dart';

void main() {
  // 纯 Dart 测试也要初始化 binding：TestDefaultBinaryMessengerBinding.instance 依赖它。
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      PetWindowService.channel,
      (call) async {
        calls.add(call);
        // 原生侧返回「操作后是否可见」：toggle 第一次开、第二次关。
        return calls.where((c) => c.method == 'toggle').length.isOdd;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      PetWindowService.channel,
      null,
    );
  });

  test('非 Windows 一律 false，且不碰通道', () async {
    const service = PetWindowService(supported: false);

    expect(service.isSupported, isFalse);
    expect(await service.toggle(), isFalse);
    expect(await service.isVisible(), isFalse);
    expect(calls, isEmpty, reason: 'Android/桌面之外的平台没有这个窗口，发消息只会得到 MissingPluginException');
  });

  test('toggle 返回原生给的真实状态（不是我们猜的）', () async {
    const service = PetWindowService(supported: true);

    expect(await service.toggle(), isTrue);
    expect(await service.toggle(), isFalse);
    expect(calls.map((c) => c.method), ['toggle', 'toggle']);
  });

  test('isVisible 走独立方法，不复用 toggle', () async {
    const service = PetWindowService(supported: true);

    await service.isVisible();
    expect(calls.single.method, 'isVisible');
    expect(calls.any((c) => c.method == 'toggle'), isFalse, reason: '查询状态绝不能顺手把窗口开关一次');
  });

  test('toggle 把签到天数带过去（第二个 engine 读不到主应用状态）', () async {
    const service = PetWindowService(supported: true);

    await service.toggle(days: 12);
    await service.toggle();

    // 参数按位置：[0]=days（缺省占位 -1）、[1]=personality（可选）。
    expect(calls[0].arguments, [12]);
    expect(calls[1].arguments, [-1], reason: '不知道天数用 -1 占位，宠物用默认形态');
  });

  test('toggle 把性格带过去（P2-3：宠物台词与主应用同性格）', () async {
    const service = PetWindowService(supported: true);

    await service.toggle(days: 12, personality: 'calm');
    await service.toggle(personality: 'stubborn');

    expect(calls[0].arguments, [12, 'calm']);
    expect(calls[1].arguments, [-1, 'stubborn'], reason: '天数缺省占位 -1，性格照常带过去');
  });
}
