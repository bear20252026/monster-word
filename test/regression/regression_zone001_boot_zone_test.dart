import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// REG-ZONE-001：启动 zone 契约守卫。
///
/// 历史 bug：main() 里先 `await bootstrapApp()`（内部 ensureInitialized，
/// 落在根 zone），再用 runZonedGuarded 包 runApp（新 zone）——绑定 zone 与
/// 运行 zone 不一致，Flutter 每次冷启动打 Zone mismatch 告警。
///
/// 契约：runZonedGuarded 是 main() 的第一条语句，bootstrapApp 与 runApp
/// 都必须出现在 guarded 回调内部。任何在进入 zone 之前 await 的写法都会
/// 让绑定初始化落回根 zone，本测试直接拦截。
void main() {
  final source = File('lib/main.dart').readAsStringSync();

  // 提取 main() 函数体（从签名到文件末尾的最后一个 `}` 之前）。
  final mainStart = source.indexOf('Future<void> main() async {');
  test('REG-ZONE-001: main() exists and delegates everything into runZonedGuarded', () {
    expect(mainStart, greaterThanOrEqualTo(0), reason: 'lib/main.dart 必须有 main() 入口');
    final body = source.substring(mainStart);

    final zoneCall = body.indexOf('runZonedGuarded(');
    expect(zoneCall, greaterThanOrEqualTo(0), reason: 'main() 必须用 runZonedGuarded 包裹启动流程');

    // main() 进入 zone 之前的引导段（签名行与 runZonedGuarded 之间）不允许 await：
    // 任何提前 await 都可能把绑定初始化留在根 zone。
    final preamble = body.substring(0, zoneCall);
    expect(
      RegExp(r'^\s*await\b').hasMatch(preamble),
      isFalse,
      reason: 'runZonedGuarded 必须是 main() 的第一条语句——之前不能有 await',
    );

    // bootstrapApp（内含 ensureInitialized）与 runApp 必须都在 zone 回调内。
    expect(body.indexOf('bootstrapApp()'), greaterThan(zoneCall), reason: 'bootstrapApp() 必须在 runZonedGuarded 回调内部执行');
    expect(
      body.indexOf('runApp(const WordApp());'),
      greaterThan(zoneCall),
      reason: 'runApp 必须在 runZonedGuarded 回调内部执行',
    );
  });
}
