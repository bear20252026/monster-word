// R3-L07 回归守卫：`sl.reset()` 之后必须能重建依赖，不能让 re-attach 崩在
// `WordApp.build` 的第一行 `sl<AudioService>()`。
//
// 审计原判：`app.dart:159-163` 在 `detached` 时调 `disposeServiceLocator()`
//（内含 `sl.reset()`），而 `setupServiceLocator()` 只在 bootstrap 调一次；
// 平台允许同一 engine detach 后再次 attach（widget 树未拆、`build` 会重跑）
// ⇒ `StateError` + 静态单例已被 release（发音永久失效）。
//
// 修复：`ensureServiceLocatorReady()` —— 只在「注册表为空」时重建，
// 由 `WordApp.build` 在取 `sl<AudioService>()` 之前调用。
//
// 本文件**不打桩**、直接操作真实的 `sl`（GetIt 全局单例），
// 因此每个用例后都把注册表恢复到干净状态，避免污染同进程的其他测试。

import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/app/service_locator.dart';
import 'package:word_app/core/audio/audio_service.dart';
import 'package:word_app/core/repositories/word_repository.dart';

void main() {
  tearDown(() async {
    // 恢复：先清空再重建，保证后续测试看到的是「已装配」的正常状态。
    await sl.reset();
    await setupServiceLocator();
  });

  test('R3-L07：reset 后 ensureServiceLocatorReady 能重建依赖（re-attach 不再崩）', () async {
    await sl.reset();
    expect(sl.isRegistered<AudioService>(), isFalse, reason: '前提：reset 后注册表确实为空');

    final rebuilt = await ensureServiceLocatorReady();

    expect(rebuilt, isTrue, reason: '注册表为空时应当真的重建');
    expect(sl.isRegistered<AudioService>(), isTrue, reason: 'WordApp.build 的首个依赖必须能取到');
    expect(sl.isRegistered<WordRepository>(), isTrue, reason: '其余注册也应一并恢复，不能只补一个 AudioService');
    // 真实取一次，确认不是「注册了但工厂抛错」。
    expect(sl<AudioService>(), isNotNull);
  });

  test('R3-L07：已装配时是空操作（不能每次 build 都重跑几十个注册）', () async {
    await setupServiceLocator();
    final rebuilt = await ensureServiceLocatorReady();

    expect(rebuilt, isFalse, reason: '已注册 ⇒ 必须直接返回，这是热重载下每次 build 的常态路径');
    expect(sl.isRegistered<AudioService>(), isTrue);
  });

  test('R3-L07：重复调用 setupServiceLocator 幂等（重建不会重复注册而抛错）', () async {
    await setupServiceLocator();
    await setupServiceLocator(); // 不得抛「already registered」

    expect(sl.isRegistered<AudioService>(), isTrue);
    expect(sl.isRegistered<WordRepository>(), isTrue);
  });

  test('R3-L07：dispose 后立刻恢复，模拟 detached → re-attach 的完整序列', () async {
    await setupServiceLocator();
    sl<AudioService>(); // 实例化一次，模拟运行期已用过

    await disposeServiceLocator();
    expect(sl.isRegistered<AudioService>(), isFalse, reason: 'detach 会抹空注册表（这是既有行为）');

    final rebuilt = await ensureServiceLocatorReady();
    expect(rebuilt, isTrue);
    expect(sl<AudioService>(), isNotNull, reason: 're-attach 后发音必须可用，不能永久失效');
  });
}
