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
// 本文件**不打桩**、直接操作真实的 `sl`（GetIt 全局单例），因此用 setUp/tearDown
// 把注册表清干净，避免污染同 isolate 内的其他用例。
//
// ⚠️ 断言一律用 `isRegistered<T>()` 而**不 fetch 实例**：
// `AudioServiceImpl` 的字段初始化器是 `final AudioPlayer _player = AudioPlayer()`
//（`audio_player_core.dart:12`），会在构造期创建 just_audio 平台通道 ——
// 在无插件的 `flutter test` 里是不必要的副作用。本文件验的是「注册表被恢复」，
// 不是「实例能造出来」，所以只查注册状态。

import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/app/service_locator.dart';
import 'package:word_app/core/audio/audio_service.dart';
import 'package:word_app/core/repositories/word_repository.dart';

void main() {
  // 每个用例前后都把全局 `sl` 清干净：
  // 「注册表初始为空」是被测行为的显式前提，不能碰巧依赖上一个用例的 tearDown。
  //
  // 「重建」这件事本身就是被测行为，由各用例显式触发才看得清，故不在这里代劳。
  setUp(() async => sl.reset());
  tearDown(() async => sl.reset());

  test('R3-L07：reset 后 ensureServiceLocatorReady 能重建依赖（re-attach 不再崩）', () async {
    expect(sl.isRegistered<AudioService>(), isFalse, reason: '前提：reset 后注册表确实为空');

    final rebuilt = await ensureServiceLocatorReady();

    expect(rebuilt, isTrue, reason: '注册表为空时应当真的重建');
    expect(sl.isRegistered<AudioService>(), isTrue, reason: 'WordApp.build 的首个依赖必须能取到');
    expect(sl.isRegistered<WordRepository>(), isTrue, reason: '其余注册也应一并恢复，不能只补一个 AudioService');
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
    // ⚠️ 此处在 reset 之后**不重新注册真实实现**再调 dispose：
    // `disposeServiceLocator` 会 `sl<AudioService>().dispose()`，而真实
    // `AudioServiceImpl` 的字段初始化器 `final AudioPlayer _player = AudioPlayer()`
    //（`audio_player_core.dart:12`）会在构造期创建 just_audio 平台通道。
    // 本用例验的是「reset 之后能否恢复」，与具体实现无关，故跳过实例化。
    await sl.reset();

    // detach 路径：注册表已空时也必须不抛（`disposeServiceLocator` 有 isRegistered 守卫）。
    await disposeServiceLocator();
    expect(sl.isRegistered<AudioService>(), isFalse, reason: 'detach 会抹空注册表（这是既有行为）');

    final rebuilt = await ensureServiceLocatorReady();
    expect(rebuilt, isTrue);
    expect(sl.isRegistered<AudioService>(), isTrue, reason: 're-attach 后发音必须可用，不能永久失效');
    expect(sl.isRegistered<WordRepository>(), isTrue, reason: '整张注册表都要回来，不能只补首个依赖');
  });
}
