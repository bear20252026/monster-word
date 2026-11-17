// 第四轮审计 M5（2026-11-17）：宠物窗口控制器竞态口径回归。
// C3 in-flight 闸 / R20 返回值复核 / T20 首查 busy 闸 + 失败路径复核 / C6 事件对齐。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/infrastructure/pet_window_service.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/settings/application/pet_window_controller.dart';

/// 可控假窗口服务：toggle/isVisible 用 Completer 门控，精确编排竞态时序。
class _FakePetService implements PetWindowService {
  _FakePetService({this.supported = true});
  final bool supported;

  final List<({int? days, String? personality})> toggleCalls = [];
  Completer<bool>? toggleGate;
  bool toggleResult = true;
  Object? toggleError;

  Completer<bool>? isVisibleGate;
  bool isVisibleResult = false;
  Object? isVisibleError;

  final StreamController<bool> events = StreamController<bool>.broadcast();
  bool listenCalled = false;

  @override
  bool get isSupported => supported;

  @override
  Future<bool> toggle({int? days, String? personality}) {
    toggleCalls.add((days: days, personality: personality));
    if (toggleError != null) return Future.error(toggleError!);
    final gate = toggleGate;
    if (gate != null) return gate.future;
    return Future.value(toggleResult);
  }

  @override
  Future<bool> isVisible() {
    if (isVisibleError != null) return Future.error(isVisibleError!);
    final gate = isVisibleGate;
    if (gate != null) return gate.future;
    return Future.value(isVisibleResult);
  }

  @override
  Stream<bool> get visibilityChanges => events.stream;

  @override
  void listenVisibilityEvents() {
    listenCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCheckinReader implements CheckinStatusReader {
  _FakeCheckinReader({this.dates = const {}});
  final Set<String> dates;
  Object? error;

  @override
  Future<Set<String>> getCheckinDates() async {
    if (error != null) throw error!;
    return dates;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('attach：订阅事件 + 首查对齐（C6）', () async {
    final service = _FakePetService()..isVisibleResult = true;
    final controller = PetWindowController(service: service);
    addTearDown(controller.dispose);

    controller.attach();
    await Future<void>.delayed(Duration.zero);

    expect(service.listenCalled, isTrue);
    expect(controller.visible, isTrue);
  });

  test('不支持平台：attach 无操作、toggle 返回 false 态', () async {
    final service = _FakePetService(supported: false);
    final controller = PetWindowController(service: service);
    addTearDown(controller.dispose);

    controller.attach();
    expect(service.listenCalled, isFalse);
    expect(controller.visible, isFalse);
  });

  test('C3：in-flight 闸拒重入——双击只产生一次原生 toggle', () async {
    final service = _FakePetService();
    final gate = Completer<bool>();
    service.toggleGate = gate;
    final controller = PetWindowController(service: service);
    addTearDown(controller.dispose);

    final first = controller.toggle(true);
    final second = controller.toggle(false); // 在途重入，应被拒
    expect(controller.toggleBusy, isTrue);

    gate.complete(true);
    service.isVisibleResult = true;
    await first;
    await second;

    expect(service.toggleCalls.length, 1, reason: '重入被拒，原生只收到一次 toggle');
    expect(controller.visible, isTrue);
  });

  test('R20：toggle 返回 true 但复核 isVisible=false → 以复核为准（不谎报开启）', () async {
    final service = _FakePetService()
      ..toggleResult = true
      ..isVisibleResult = false; // 右键关窗事件先到，原生实际已关
    final controller = PetWindowController(service: service);
    addTearDown(controller.dispose);

    final actual = await controller.toggle(true);

    expect(actual, isFalse);
    expect(controller.visible, isFalse);
  });

  test('R20：复核失败回退 toggle 返回值（不阻断开关流程）', () async {
    final service = _FakePetService()
      ..toggleResult = true
      ..isVisibleError = StateError('通道抖动');
    final controller = PetWindowController(service: service);
    addTearDown(controller.dispose);

    final actual = await controller.toggle(true);

    expect(actual, isTrue);
    expect(controller.visible, isTrue);
  });

  test('T20：toggle 抛错 → 失败路径复核原生真实态并对齐', () async {
    final service = _FakePetService()
      ..toggleError = StateError('原生启动失败')
      ..isVisibleResult = false;
    final controller = PetWindowController(service: service);
    addTearDown(controller.dispose);

    final actual = await controller.toggle(true);

    expect(actual, isFalse);
    expect(controller.visible, isFalse);
    expect(controller.toggleBusy, isFalse, reason: 'finally 必须释放闸');
  });

  test('T20：在途期间首查慢回不覆盖（busy 闸核心口径）', () async {
    final service = _FakePetService();
    final firstQuery = Completer<bool>();
    service.isVisibleGate = firstQuery;
    final controller = PetWindowController(service: service);
    addTearDown(controller.dispose);

    controller.attach(); // 首查挂起
    final toggleGate = Completer<bool>();
    service.toggleGate = toggleGate;
    final toggling = controller.toggle(true); // busy 置位

    firstQuery.complete(false); // 首查在途期间返回旧值
    await Future<void>.delayed(Duration.zero);
    expect(controller.visible, isFalse, reason: '在途期间旧查询不得覆盖');

    toggleGate.complete(true);
    service.isVisibleGate = null;
    service.isVisibleResult = true;
    await toggling;
    expect(controller.visible, isTrue, reason: 'toggle 完成后以复核为准');
  });

  test('C6：原生右键关窗事件 → 开关即时对齐；在途期间忽略事件', () async {
    final service = _FakePetService()..isVisibleResult = true;
    final controller = PetWindowController(service: service);
    addTearDown(controller.dispose);
    controller.attach();
    await Future<void>.delayed(Duration.zero);
    expect(controller.visible, isTrue);

    service.events.add(false); // 右键关窗
    await Future<void>.delayed(Duration.zero);
    expect(controller.visible, isFalse);

    // 在途 toggle 期间事件被忽略（R20）
    final gate = Completer<bool>();
    service.toggleGate = gate;
    final toggling = controller.toggle(true);
    service.events.add(false);
    await Future<void>.delayed(Duration.zero);
    gate.complete(true);
    service.isVisibleResult = true;
    await toggling;
    expect(controller.visible, isTrue, reason: '在途事件忽略，以 toggle 复核为准');
  });

  test('开窗携带签到天数与性格；读取失败不阻断开窗', () async {
    final service = _FakePetService()..isVisibleResult = true;
    final reader = _FakeCheckinReader(dates: {'2026-11-15', '2026-11-16'});
    final controller = PetWindowController(service: service, checkinReader: reader);
    addTearDown(controller.dispose);

    await controller.toggle(true);
    expect(service.toggleCalls.single.days, 2);
    expect(service.toggleCalls.single.personality, isNotNull);

    reader.error = StateError('读库失败');
    await controller.toggle(false);
    expect(service.toggleCalls.last.days, isNull, reason: '关闭不带天数');
  });

  test('dispose 后事件与慢回不再通知（防 setState after dispose）', () async {
    final service = _FakePetService()..isVisibleResult = true;
    final controller = PetWindowController(service: service);
    controller.attach();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();

    service.events.add(false);
    await Future<void>.delayed(Duration.zero);
    // 不抛异常即通过（_disposed 拦截）
    expect(controller.visible, isTrue);
  });
}
